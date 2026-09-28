/* SPDX-License-Identifier: Apache-2.0 */
#ifndef RAW_IMAGE_WRITE_BUFFER_H
#define RAW_IMAGE_WRITE_BUFFER_H

#include "aligned_buffer.h"
#include <algorithm>

namespace rpi_imager {

// Network callback boundaries and addresses need not be sector aligned.
// Keep a bounded, aligned buffer and preserve every image byte in order.
// The sink is synchronous: it must finish using the data before returning.
class RawImageWriteBuffer {
public:
    RawImageWriteBuffer()
        : buffer_(std::max<std::size_t>(64 * 1024, GetDirectIOAlignment())) {}

    template<typename Write>
    bool Append(const char* data, std::size_t size, Write write)
    {
        if (failed_ || !buffer_) return false;
        while (size > 0) {
            const auto count = std::min(size, buffer_.size() - used_);
            std::memcpy(buffer_.data() + used_, data, count);
            used_ += count;
            data += count;
            size -= count;
            if (used_ == buffer_.size() && !Flush(write)) return false;
        }
        return true;
    }

    template<typename Write>
    bool Flush(Write write)
    {
        if (failed_ || !buffer_) return false;
        if (used_ == 0) return true;
        // Only flush a partial buffer at EOF. Never pad callback fragments:
        // padding would insert bytes into the image and invalidate its hash.
        // A final sector-aligned tail is passed to the device at its exact size.
        if (!write(reinterpret_cast<const char*>(buffer_.data()), used_)) {
            failed_ = true;
            return false;
        }
        used_ = 0;
        return true;
    }

private:
    AlignedBuffer buffer_;
    std::size_t used_ = 0;
    bool failed_ = false;
};

} // namespace rpi_imager
#endif
