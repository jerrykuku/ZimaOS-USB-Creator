/*
 * SPDX-License-Identifier: Apache-2.0
 */

#include "applicationidentity.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <QStandardPaths>

void initializeApplicationIdentity()
{
    QCoreApplication::setApplicationName(QStringLiteral("ZimaOS USB Creator"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("zimaspace.com"));
    QCoreApplication::setOrganizationName(QStringLiteral("IceWhaleTech"));
    QSettings settings;
    settings.setFallbacksEnabled(false);
    const QString migrationKey = QStringLiteral("migration/zimaSpaceIdentity");
    if (settings.value(migrationKey, false).toBool())
        return;

    const QDir data(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation));
    bool complete = true;
    // Prefer the most recent organization, then fill gaps from the original.
    // Existing IceWhaleTech settings and manifests always take precedence.
    const QStringList legacyOrganizations = {QStringLiteral("IceWhaleTech"), QStringLiteral("IceWhale"),
                                            QStringLiteral("Raspberry Pi")};
    for (const QString &organization : legacyOrganizations) {
        QCoreApplication::setOrganizationName(organization);
        const QDir legacyData(QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation));
        // macOS keys preferences by domain; other platforms use the name.
        // Read the old namespace explicitly without restoring the old domain.
#ifdef Q_OS_MACOS
        QSettings legacySettings(QSettings::NativeFormat, QSettings::UserScope,
                                 QStringLiteral("raspberrypi.com"), QCoreApplication::applicationName());
#else
        QSettings legacySettings(QSettings::NativeFormat, QSettings::UserScope,
                                 organization, QCoreApplication::applicationName());
#endif
        legacySettings.setFallbacksEnabled(false);

        if (settings.fileName() != legacySettings.fileName()) {
            const QStringList keys = legacySettings.allKeys();
            for (const QString &key : keys) {
                if (!key.startsWith(QStringLiteral("migration/")) && !settings.contains(key))
                    settings.setValue(key, legacySettings.value(key));
            }
        }

        const QStringList manifests = legacyData.entryList({QStringLiteral("manifest-*.json")},
                                                           QDir::Files | QDir::NoSymLinks);
        for (const QString &name : manifests) {
            const QString destination = data.filePath(name);
            if (QFile::exists(destination))
                continue;
            if (!QDir().mkpath(data.path()) || !QFile::copy(legacyData.filePath(name), destination)) {
                qWarning() << "Could not migrate cached OS manifest to:" << destination;
                complete = false;
            }
        }
    }
    QCoreApplication::setOrganizationName(QStringLiteral("IceWhaleTech"));

    // Keep the originals for older versions; retry failed copies next launch.
    if (complete)
        settings.setValue(migrationKey, true);
    settings.sync();
    if (settings.status() != QSettings::NoError)
        qWarning() << "Could not save migrated application settings";
}
