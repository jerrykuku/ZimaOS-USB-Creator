cmake_minimum_required(VERSION 3.22)
project(windowchrome_probe LANGUAGES CXX)

if(NOT WIN32)
    message(FATAL_ERROR "This probe exercises DWM and requires a Windows desktop session")
endif()

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
add_executable(windowchrome_probe windowchrome_windows.cpp ../../windows/windowchrome.cpp)
target_compile_features(windowchrome_probe PRIVATE cxx_std_20)
target_link_libraries(windowchrome_probe PRIVATE Qt6::Quick Qt6::QuickControls2 dwmapi)

enable_testing()
add_test(NAME windowchrome_native COMMAND windowchrome_probe)
set_tests_properties(windowchrome_native PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 30)
