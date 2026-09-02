# Linux packaging: installation and runtime checks

if (NOT CMAKE_CROSSCOMPILING)
    find_program(LSBLK "lsblk")
    if (NOT LSBLK)
        message(FATAL_ERROR "Unable to locate lsblk (used for disk enumeration)")
    endif()

    execute_process(COMMAND "${LSBLK}" "--json" OUTPUT_QUIET RESULT_VARIABLE ret)
    if (ret EQUAL "1")
        message(FATAL_ERROR "util-linux package too old. lsblk does not support --json (used for disk enumeration)")
    endif()
endif()

# Generate metainfo.xml with current version
# Output to debian/ directory for dpkg-buildpackage
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/../../debian/com.icewhaletech.zimaos-usb-creator.metainfo.xml.in"
    "${CMAKE_CURRENT_LIST_DIR}/../../debian/com.icewhaletech.zimaos-usb-creator.metainfo.xml"
    @ONLY)

install(TARGETS ${PROJECT_NAME} DESTINATION bin)

# Install udev rules granting unprivileged USB access to rpiboot/fastboot
# devices (a CM in rpiboot boot mode, and the fastboot gadget it re-enumerates
# into). Without these, libusb_open() fails for non-root users and the device
# silently never appears. Applies to both GUI and CLI builds.
install(FILES "${CMAKE_CURRENT_LIST_DIR}/99-rpiboot.rules" DESTINATION lib/udev/rules.d)

if(BUILD_CLI_ONLY)
    # CLI-only build: install CLI-specific desktop file (marked as NoDisplay)
    # Icon is still required for AppImage tooling (linuxdeploy) even though NoDisplay=true
    install(FILES "${CMAKE_CURRENT_LIST_DIR}/icon/rpi-imager.svg" DESTINATION share/icons/hicolor/scalable/apps)
    install(FILES "${CMAKE_CURRENT_LIST_DIR}/../../debian/com.icewhaletech.zimaos-usb-creator-cli.desktop" DESTINATION share/applications)
else()
    # GUI build: install full desktop integration
    install(FILES "${CMAKE_CURRENT_LIST_DIR}/icon/rpi-imager.svg" DESTINATION share/icons/hicolor/scalable/apps)
    install(FILES "${CMAKE_CURRENT_LIST_DIR}/../../debian/com.icewhaletech.zimaos-usb-creator.desktop" DESTINATION share/applications)
    install(FILES "${CMAKE_CURRENT_LIST_DIR}/../../debian/com.icewhaletech.zimaos-usb-creator.metainfo.xml" DESTINATION share/metainfo)
endif()


