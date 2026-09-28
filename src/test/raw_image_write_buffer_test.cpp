/* SPDX-License-Identifier: Apache-2.0 */
#include "raw_image_write_buffer.h"

#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef __linux__
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#endif

namespace {
void require(bool condition, const char* message)
{
    if (!condition) throw std::runtime_error(message);
}

std::vector<char> image(std::size_t size)
{
    std::vector<char> data(size);
    for (std::size_t i = 0; i < size; ++i) data[i] = static_cast<char>((i * 31 + i / 251) % 256);
    return data;
}

template<typename Write>
void stream(rpi_imager::RawImageWriteBuffer& buffer, const std::vector<char>& data, Write write)
{
    // Include the 866-byte initial fragment seen in the failing download,
    // one-byte callbacks, and callbacks crossing several output boundaries.
    const std::size_t sizes[] = {866, 1, 16383, 7, 200003, 511, 4096};
    std::size_t offset = 0, index = 0;
    while (offset < data.size()) {
        const auto size = std::min(sizes[index++ % 7], data.size() - offset);
        std::vector<char> unaligned(size + 1);
        std::memcpy(unaligned.data() + 1, data.data() + offset, size);
        require(buffer.Append(unaligned.data() + 1, size, write), "append failed");
        offset += size;
    }
    require(buffer.Flush(write), "final flush failed");
}

void testFragments()
{
    for (const auto size : {std::size_t(0), std::size_t(512), std::size_t(65536),
                            std::size_t(3 * 65536 + 512), std::size_t(65537)}) {
        const auto expected = image(size);
        std::vector<char> actual;
        rpi_imager::RawImageWriteBuffer buffer;
        auto write = [&](const char* data, std::size_t count) {
            require(reinterpret_cast<std::uintptr_t>(data) % rpi_imager::GetDirectIOAlignment() == 0,
                    "unaligned buffer address");
            require(actual.size() % rpi_imager::GetDirectIOAlignment() == 0,
                    "unaligned intermediate write boundary");
            actual.insert(actual.end(), data, data + count);
            return true;
        };
        stream(buffer, expected, write);
        require(buffer.Flush(write), "empty flush failed");
        require(actual == expected, "image bytes changed, padded, duplicated or lost");
    }
}

void testFailure()
{
    rpi_imager::RawImageWriteBuffer buffer;
    const auto data = image(256 * 1024);
    int calls = 0;
    auto reject = [&](const char*, std::size_t) { ++calls; return false; };
    require(!buffer.Append(data.data(), data.size(), reject), "write error was ignored");
    require(!buffer.Flush(reject), "failed write was retried");
    require(!buffer.Append(data.data(), 1, reject), "accepted data after failure");
    require(calls == 1, "continued writing after failure");
}

#ifdef __linux__
void testDirectIO()
{
    // TMPDIR allows testing on a disk filesystem when /tmp is tmpfs (which
    // accepts O_DIRECT but does not enforce its alignment requirements).
    const char* tempDir = std::getenv("TMPDIR");
    std::string path = std::string(tempDir ? tempDir : "/tmp") + "/zimaos-raw-write-XXXXXX";
    const int fd = mkstemp(path.data());
    require(fd >= 0, "cannot create temporary test file");
    unlink(path.c_str());
    struct Close { int fd; ~Close() { close(fd); } } cleanup{fd};
    const int flags = fcntl(fd, F_GETFL);
    if (fcntl(fd, F_SETFL, flags | O_DIRECT) != 0) {
        std::cout << "SKIP: temporary filesystem does not support O_DIRECT\n";
        return;
    }

    rpi_imager::AlignedBuffer probe(4096);
    require(static_cast<bool>(probe), "probe allocation failed");
    const auto oldResult = pwrite(fd, probe.data(), 866, 0);
    if (oldResult != -1 || errno != EINVAL) {
        std::cout << "SKIP: temporary filesystem does not enforce O_DIRECT alignment\n";
        return;
    }
    std::cout << "Reproduced: unbuffered 866-byte write fails with EINVAL\n";

    const auto expected = image(3 * 65536 + 512);
    rpi_imager::RawImageWriteBuffer buffer;
    std::size_t offset = 0;
    stream(buffer, expected, [&](const char* data, std::size_t size) {
        const auto written = pwrite(fd, data, size, static_cast<off_t>(offset));
        if (written != static_cast<ssize_t>(size)) return false;
        offset += size;
        return true;
    });
    require(fsync(fd) == 0, "sync failed");
    require(fcntl(fd, F_SETFL, flags) == 0, "cannot disable direct IO for readback");
    std::vector<char> actual(expected.size() + 1);
    const auto readSize = pread(fd, actual.data(), actual.size(), 0);
    require(readSize == static_cast<ssize_t>(expected.size()), "wrong output size");
    actual.resize(expected.size());
    require(actual == expected, "direct IO readback differs from the image");
    std::cout << "PASS: fragmented download through O_DIRECT matches every input byte\n";
}
#endif
}

int main()
{
    try {
        testFragments();
        testFailure();
#ifdef __linux__
        testDirectIO();
#endif
        std::cout << "PASS: alignment, fragment boundaries, exact EOF and error propagation\n";
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
