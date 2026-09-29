/* SPDX-License-Identifier: Apache-2.0 */
#include "../imageselectionpolicy.h"
#include <QDebug>

// This policy needs only QtCore and can also be run without the app or hardware.
int main()
{
    using namespace ImageSelectionPolicy;
    auto image = [](const char *name, bool recommended = false) {
        return QJsonObject{{"name", name}, {"url", "https://example.com/image.img"}, {"recommended", recommended}};
    };
    int failures = 0;
    auto check = [&](bool ok, const char *message) {
        if (!ok) { qCritical() << message; ++failures; }
    };
    QJsonArray releases{image("ZimaOS 1.8.0 Beta", true), image("ZimaOS 1.7.1", true), image("ZimaOS 1.7.0")};
    check(recommendedIndex(releases, "") == 1, "A leading recommended beta must not be the default");
    check(recommendedIndex(releases, "ZimaOS 1.7.0") == 2, "An explicit stable default takes priority");
    check(recommendedIndex(releases, "ZimaOS 1.8.0 Beta") == 1, "A prerelease default must not override stable recommendations");
    check(recommendedIndex({image("ZimaOS 1.9.0"), image("ZimaOS 1.10.0")}, "") == 1, "Fallback versions must be compared numerically");
    check(recommendedIndex({image("ZimaOS 2.0.0-rc1"), image("ZimaOS 2.0.0 nightly")}, "") == -1, "No automatic choice in a prerelease-only repository");
    check(recommendedIndex({image("Custom Linux"), image("Another OS")}, "") == -1, "Third-party repositories need an explicit recommendation");
    check(recommendedIndex({}, "") == -1, "Empty lists have no default");
    auto stable = image("Custom Linux"); stable["description"] = "An image (Recommended)";
    check(recommendedIndex({image("Another OS"), stable}, "") == 1, "Legacy manifest recommendations are preserved");
    for (const char *name : {"OS Alpha", "OS BETA2", "OS rc1", "OS Preview", "OS nightly", "OS dev"})
        check(isPrerelease(image(name)), name);
    check(!isPrerelease(image("Debian Bookworm")), "Substring matches must not label stable names as prereleases");
    auto preview = image("ZimaOS 3.0.0", true); preview["prerelease"] = true;
    check(recommendedIndex({preview}, "") == -1, "Structured prerelease flags are respected");
    preview["prerelease"] = false; preview["release_channel"] = "beta";
    check(isPrerelease(preview), "Release channels are respected");
    auto category = image("Category", true); category["subitems_json"] = "[]";
    auto custom = image("Custom", true); custom["url"] = "internal://custom";
    auto format = image("Erase", true); format["url"] = "internal://format";
    check(recommendedIndex({category, custom, format}, "") == -1, "Categories and internal actions cannot be automatic choices");
    if (!failures) qInfo() << "PASS: image selection policy";
    return failures ? 1 : 0;
}
