cmake_minimum_required(VERSION 3.22)
project(windowchrome_probe LANGUAGES CXX)

if(NOT WIN32)
    message(FATAL_ERROR "This probe exercises DWM and requires a Windows desktop session")
endif()

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
add_executable(windowchrome_probe windowchrome_windows.cpp ../../windows/windowchrome.cpp)
target_compile_features(windowchrome_probe PRIVATE cxx_std_20)
target_link_libraries(windowchrome_probe PRIVATE Qt6::Quick Qt6::QuickControls2 dwmapi gdi32 user32)
qt_add_resources(windowchrome_probe "window_frame" PREFIX "/"
    BASE "../../qmlcomponents" FILES "../../qmlcomponents/WindowFrameBackground.qml")

enable_testing()
add_test(NAME windowchrome_native COMMAND windowchrome_probe)
add_test(NAME windowchrome_software_fallback COMMAND windowchrome_probe --software)
set_tests_properties(windowchrome_software_fallback PROPERTIES ENVIRONMENT "QT_QUICK_BACKEND=software")
set_tests_properties(windowchrome_native windowchrome_software_fallback
    PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 30 RUN_SERIAL TRUE)
