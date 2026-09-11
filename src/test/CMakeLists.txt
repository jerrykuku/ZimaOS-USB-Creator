# Test configuration for rpi-imager
# Uses Catch2 and CTest for testing

# Fetch Catch2 for testing
include(FetchContent)

FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.5.2
    FIND_PACKAGE_ARGS NAMES Catch2
)

FetchContent_MakeAvailable(Catch2)

# Include Catch2 CMake utilities for test discovery
list(APPEND CMAKE_MODULE_PATH ${catch2_SOURCE_DIR}/extras)
include(Catch)

# Register a Catch2 binary's cases with CTest.
#
# Wraps catch_discover_tests purely to pin SKIP_RETURN_CODE. Catch2 exits 4 when
# every selected case was skipped, and because discovery registers one CTest test
# per case, a case that calls SKIP() is always the only one selected — so without
# this CTest reports every skip as a failure. Tests that skip when optional
# fixtures or hardware are absent (the pieeprom and eeprom_signer ones) were
# accounting for six phantom failures. Use this in place of
# catch_discover_tests() so a new test binary cannot reintroduce them.
function(rpi_discover_tests target)
    catch_discover_tests(${target} PROPERTIES SKIP_RETURN_CODE 4)
endfunction()

# Add the customization generator test executable
# Includes the bundled crypto sources the generator now depends on for
# credential derivation (yescrypt/sha256crypt password hashing).
add_executable(customization_generator_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../customization_generator.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../customization_generator.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../dependencies/sha256crypt/sha256crypt.c
    customization_generator_test.cpp
)

# Link against Catch2, Qt and the bundled yescrypt static library
# (yescrypt is defined in the parent scope via dependencies/yescrypt.cmake and
# carries its include directory as a PUBLIC usage requirement).
target_link_libraries(customization_generator_test PRIVATE 
    Catch2::Catch2WithMain
    Qt6::Core
    Qt6::Network
    yescrypt
)

# Include parent directory for headers
target_include_directories(customization_generator_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_compile_features(customization_generator_test PRIVATE cxx_std_20)
target_compile_options(customization_generator_test PRIVATE 
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

# Register with CTest for automatic test discovery
rpi_discover_tests(customization_generator_test)

# Also add a custom target for manual running
add_custom_target(test_customization_generator
    COMMAND customization_generator_test
    DEPENDS customization_generator_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running customization generator tests"
)

# Determine platform-specific file operations implementation for FAT partition test
if(WIN32)
    set(PLATFORM_FILE_OPS
        ${CMAKE_CURRENT_SOURCE_DIR}/../windows/file_operations_windows.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../windows/file_operations_windows.cpp
    )
elseif(APPLE)
    set(PLATFORM_FILE_OPS
        ${CMAKE_CURRENT_SOURCE_DIR}/../mac/file_operations_macos.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../mac/file_operations_macos.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../mac/macfile.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../mac/macfile.cpp
    )
else()
    set(PLATFORM_FILE_OPS
        ${CMAKE_CURRENT_SOURCE_DIR}/../linux/file_operations_linux.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../linux/file_operations_linux.cpp
    )
endif()

# Add the FAT partition test executable (manual test against real filesystem)
add_executable(fat_partition_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapper.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapper.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperpartition.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperpartition.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperblockcacheentry.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperblockcacheentry.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperfatpartition.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../devicewrapperfatpartition.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.cpp
    ${PLATFORM_FILE_OPS}
    ${CMAKE_CURRENT_SOURCE_DIR}/../fat_partition_test.cpp
)

# Enable Qt MOC for Q_OBJECT classes
set_target_properties(fat_partition_test PROPERTIES
    AUTOMOC ON
)

# Link Catch2 and Qt libraries
target_link_libraries(fat_partition_test PRIVATE
    Catch2::Catch2WithMain
    Qt6::Core
)

# Link platform-specific libraries
if(APPLE)
    target_link_libraries(fat_partition_test PRIVATE
        "-framework Security"
        "-framework DiskArbitration"
        "-framework CoreFoundation"
    )
endif()

# Include parent directory for headers
target_include_directories(fat_partition_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_compile_features(fat_partition_test PRIVATE cxx_std_20)
target_compile_options(fat_partition_test PRIVATE 
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

# Register with CTest for automatic test discovery
# Note: These tests are marked with [!mayfail] and [.destructive] tags
# Run with: ctest -C Debug --output-on-failure
# Or with environment variable: FAT_TEST_MOUNT_PATH="/Volumes/bootfs 1" ctest
rpi_discover_tests(fat_partition_test)

# Custom target for manual running with mount path argument
# Usage: FAT_TEST_MOUNT_PATH="/Volumes/bootfs 1" cmake --build . --target test_fat_partition
add_custom_target(test_fat_partition
    COMMAND echo "Set FAT_TEST_MOUNT_PATH environment variable and run: ./test/fat_partition_test"
    COMMAND echo "Example: FAT_TEST_MOUNT_PATH=\"/Volumes/bootfs 1\" ./test/fat_partition_test"
    DEPENDS fat_partition_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "FAT partition test built - set FAT_TEST_MOUNT_PATH to run"
)

# ============================================================================
# Drivelist Tests
# ============================================================================

# Determine platform-specific drivelist implementation
if(WIN32)
    set(DRIVELIST_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../drivelist/drivelist_windows.cpp
    )
    set(DRIVELIST_PLATFORM_LIBS setupapi)
elseif(APPLE)
    set(DRIVELIST_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../drivelist/drivelist_darwin.mm
    )
    set(DRIVELIST_PLATFORM_LIBS
        "-framework DiskArbitration"
        "-framework IOKit"
        "-framework Cocoa"
        "-framework CoreFoundation"
    )
else()
    set(DRIVELIST_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../drivelist/drivelist_linux.cpp
    )
    set(DRIVELIST_PLATFORM_LIBS "")
endif()

# Add the drivelist test executable
add_executable(drivelist_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../drivelist/drivelist.h
    ${DRIVELIST_PLATFORM_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/../drivelist/drivelist_test.cpp
)

# Enable test API for access to parsing functions
target_compile_definitions(drivelist_test PRIVATE DRIVELIST_ENABLE_TEST_API)

# Link against Catch2, Qt, and platform libraries
target_link_libraries(drivelist_test PRIVATE
    Catch2::Catch2WithMain
    Qt6::Core
    ${DRIVELIST_PLATFORM_LIBS}
)

# Include parent directory for headers
target_include_directories(drivelist_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_compile_features(drivelist_test PRIVATE cxx_std_20)
target_compile_options(drivelist_test PRIVATE
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

# Register with CTest for automatic test discovery
rpi_discover_tests(drivelist_test)

# Custom target for manual running
add_custom_target(test_drivelist
    COMMAND drivelist_test
    DEPENDS drivelist_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running drivelist tests"
)

# ============================================================================
# PlatformQuirks Tests
# ============================================================================

# Determine platform-specific platformquirks implementation
if(WIN32)
    set(PLATFORMQUIRKS_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../windows/platformquirks_windows.cpp
    )
    set(PLATFORMQUIRKS_LIBS
        ws2_32
        iphlpapi
        wbemuuid
        ole32
        oleaut32
    )
elseif(APPLE)
    set(PLATFORMQUIRKS_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../mac/platformquirks_macos.mm
    )
    set(PLATFORMQUIRKS_LIBS
        "-framework AppKit"
        "-framework SystemConfiguration"
        "-framework DiskArbitration"
        "-framework CoreFoundation"
        "-framework CoreServices"  # LSSetDefaultHandlerForURLScheme (registerUriScheme)
    )
else()
    set(PLATFORMQUIRKS_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/../linux/platformquirks_linux.cpp
    )
    set(PLATFORMQUIRKS_LIBS "")
endif()

# Add the platformquirks test executable
add_executable(platformquirks_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../platformquirks.h
    ${PLATFORMQUIRKS_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/platformquirks_test.cpp
)

# Enable test API for Windows parseDeviceNumber
target_compile_definitions(platformquirks_test PRIVATE PLATFORMQUIRKS_ENABLE_TEST_API)

# Link against Catch2, Qt, and platform libraries
target_link_libraries(platformquirks_test PRIVATE
    Catch2::Catch2WithMain
    Qt6::Core
    ${PLATFORMQUIRKS_LIBS}
)

# Include parent directory for headers
target_include_directories(platformquirks_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_compile_features(platformquirks_test PRIVATE cxx_std_20)
target_compile_options(platformquirks_test PRIVATE
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

# Register with CTest for automatic test discovery
rpi_discover_tests(platformquirks_test)

# Custom target for manual running
add_custom_target(test_platformquirks
    COMMAND platformquirks_test
    DEPENDS platformquirks_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running platformquirks tests"
)

# ============================================================================
# Disk Formatter Tests
# ============================================================================

# Standalone test (not Catch2) — uses POSIX fork/exec for system tool validation
if(NOT WIN32)
    add_executable(disk_formatter_test
        ${CMAKE_CURRENT_SOURCE_DIR}/../disk_formatter.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../disk_formatter.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.h
        ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../aligned_buffer.h
        ${PLATFORM_FILE_OPS}
        disk_formatter_test.cpp
    )

    # Enable Qt MOC for Q_OBJECT classes (e.g. MacFile on macOS)
    set_target_properties(disk_formatter_test PROPERTIES AUTOMOC ON)

    target_include_directories(disk_formatter_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    )

    # Qt6::Core needed by platform file_operations (QFile, QDebug)
    target_link_libraries(disk_formatter_test PRIVATE
        Qt6::Core
    )

    target_compile_features(disk_formatter_test PRIVATE cxx_std_20)
    target_compile_options(disk_formatter_test PRIVATE
        -Wall -Wextra -Wpedantic
        $<$<CONFIG:Debug>:-g -O0>
    )

    if(APPLE)
        target_link_libraries(disk_formatter_test PRIVATE
            "-framework Security"
            "-framework DiskArbitration"
            "-framework CoreFoundation"
        )
    endif()

    add_custom_target(test_disk_formatter
        COMMAND disk_formatter_test
        DEPENDS disk_formatter_test
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running disk formatter tests"
    )
endif()

# ============================================================================
# Device I/O Limits Diagnostic Test
# ============================================================================
# Reports raw DeviceIOLimits values for all connected drives.
# Validates the queue-depth and max-transfer heuristics against real hardware.

add_executable(device_io_limits_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../file_operations.cpp
    ${PLATFORM_FILE_OPS}
    device_io_limits_test.cpp
)

set_target_properties(device_io_limits_test PROPERTIES AUTOMOC ON)

target_include_directories(device_io_limits_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(device_io_limits_test PRIVATE
    Catch2::Catch2WithMain
    Qt6::Core
)

if(APPLE)
    target_link_libraries(device_io_limits_test PRIVATE
        "-framework Security"
        "-framework DiskArbitration"
        "-framework CoreFoundation"
    )
endif()

target_compile_features(device_io_limits_test PRIVATE cxx_std_20)

rpi_discover_tests(device_io_limits_test)

add_custom_target(test_device_io_limits
    COMMAND device_io_limits_test
    DEPENDS device_io_limits_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running device I/O limits diagnostic"
)
# BlockBatcher coalesces libarchive data blocks into larger writes during
# multi-file extraction. Header-only and free of Qt/libarchive, so it tests without
# a download, a ring buffer or a device attached.
add_executable(block_batcher_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../block_batcher.h
    block_batcher_test.cpp
)

target_link_libraries(block_batcher_test PRIVATE
    Catch2::Catch2WithMain
)

target_include_directories(block_batcher_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_compile_features(block_batcher_test PRIVATE cxx_std_20)
target_compile_options(block_batcher_test PRIVATE
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

rpi_discover_tests(block_batcher_test)

add_custom_target(test_block_batcher
    COMMAND block_batcher_test
    DEPENDS block_batcher_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running block batcher tests"
)

# ============================================================================
# RingBuffer Slot Recycling Tests
# ============================================================================
# The write path uses the ring buffer as a slot pool for asynchronous I/O, whose
# completions release slots out of order. Covers that a released slot -- and only
# that slot -- is recycled, so a buffer still being read from is never handed
# back to the producer. Needs Qt6::Core for qMallocAligned/qDebug.

add_executable(ringbuffer_test
    ${CMAKE_CURRENT_SOURCE_DIR}/../ringbuffer.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../ringbuffer.cpp
    ringbuffer_test.cpp
)

target_include_directories(ringbuffer_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

target_link_libraries(ringbuffer_test PRIVATE
    Catch2::Catch2WithMain
    Qt6::Core
)

target_compile_features(ringbuffer_test PRIVATE cxx_std_20)
target_compile_options(ringbuffer_test PRIVATE
    -Wall -Wextra -Wpedantic
    $<$<CONFIG:Debug>:-g -O0>
)

rpi_discover_tests(ringbuffer_test)

add_custom_target(test_ringbuffer
    COMMAND ringbuffer_test
    DEPENDS ringbuffer_test
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running ring buffer tests"
)

# ============================================================================
# Embedded Display Scaling Matrix
# ============================================================================
# applyEmbeddedDisplayScaling() chooses the embedded UI scale by reading the
# connected display out of /sys/class/drm, so the cases that matter -- a
# 43-inch-class 4K TV on a desk, the same set with no usable EDID, a DSI panel
# that reports no physical size -- are unreachable from an ordinary unit test,
# which only ever sees the build host's own display.
#
# embedded_scaling/run.sh drives the real code instead: per case it builds a
# synthetic /sys/class/drm, bind-mounts it over the real one inside an
# unprivileged mount namespace, and checks the factor chosen. This probe is
# what it runs inside that namespace. Linux-only, and it skips itself (exit 4)
# where the host cannot provide the namespace.

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_executable(embedded_scaling_probe
        ${CMAKE_CURRENT_SOURCE_DIR}/../platformquirks.h
        ${PLATFORMQUIRKS_SOURCES}
        ${CMAKE_CURRENT_SOURCE_DIR}/embedded_scaling_probe.cpp
    )

    target_link_libraries(embedded_scaling_probe PRIVATE
        Qt6::Core
        ${PLATFORMQUIRKS_LIBS}
    )

    target_include_directories(embedded_scaling_probe PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    )

    target_compile_features(embedded_scaling_probe PRIVATE cxx_std_20)
    target_compile_options(embedded_scaling_probe PRIVATE
        -Wall -Wextra -Wpedantic
        $<$<CONFIG:Debug>:-g -O0>
    )

    add_test(NAME embedded_scaling_matrix
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/embedded_scaling/run.sh
                $<TARGET_FILE:embedded_scaling_probe>
    )
    set_tests_properties(embedded_scaling_matrix PROPERTIES SKIP_RETURN_CODE 4)

    add_custom_target(test_embedded_scaling
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/embedded_scaling/run.sh
                $<TARGET_FILE:embedded_scaling_probe>
        DEPENDS embedded_scaling_probe
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running embedded display scaling matrix"
    )

    # The matrix above proves which factor is chosen; screenshots.sh renders the
    # UI at it. That needs the app itself, so the target only appears in a GUI
    # build; only an embedded one lays out the way the netboot imager does; and
    # it needs the screenshot hook, which is compiled out unless a test build
    # asks for it (-DENABLE_TEST_HOOKS=ON). Not a CTest test: it wants fonts and
    # several seconds per profile, and its output is meant to be looked at.
    if(TARGET zimaos-usb-creator AND BUILD_EMBEDDED AND ENABLE_TEST_HOOKS)
        add_custom_target(screenshots_embedded_scaling
            COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/embedded_scaling/screenshots.sh
                    $<TARGET_FILE:zimaos-usb-creator>
                    ${CMAKE_CURRENT_BINARY_DIR}/embedded_scaling_screenshots
            DEPENDS zimaos-usb-creator
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "Rendering the embedded UI at each display profile"
        )
    endif()
endif()
