/* SPDX-License-Identifier: Apache-2.0 */
#ifndef IMAGESELECTIONPOLICY_H
#define IMAGESELECTIONPOLICY_H

#include <QJsonArray>
#include <QJsonObject>
#include <QRegularExpression>
#include <QVersionNumber>

namespace ImageSelectionPolicy {

inline bool isPrerelease(const QJsonObject &entry)
{
    static const QRegularExpression preview(
        QStringLiteral("(?:^|[^a-z])(?:alpha|beta|rc|preview|nightly|dev)(?:[0-9]|\\b)"),
        QRegularExpression::CaseInsensitiveOption);
    return entry.value("prerelease").toBool() ||
        preview.match(entry.value("name").toString() + " " + entry.value("release_channel").toString()).hasMatch();
}

inline bool isImage(const QJsonObject &entry)
{
    const QString url = entry.value("url").toString();
    return !url.isEmpty() && !url.startsWith("internal://") &&
        entry.value("subitems").toArray().isEmpty() &&
        entry.value("subitems_json").toString().isEmpty() &&
        entry.value("subitems_url").toString().isEmpty();
}

// Respect repository recommendations. Only infer a fallback among versioned
// ZimaOS releases; arbitrary third-party repositories must opt in explicitly.
inline int recommendedIndex(const QJsonArray &entries, const QString &defaultName)
{
    static const QRegularExpression legacyRecommendation(QStringLiteral("\\(Recommended\\)"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression zimaVersion(QStringLiteral("^ZimaOS\\s+(\\d+\\.\\d+(?:\\.\\d+)?)$"), QRegularExpression::CaseInsensitiveOption);
    int explicitRecommendation = -1;
    int latestStable = -1;
    QVersionNumber latestVersion;
    for (qsizetype i = 0; i < entries.size(); ++i) {
        const QJsonObject entry = entries[i].toObject();
        if (!isImage(entry) || isPrerelease(entry))
            continue;
        if (!defaultName.isEmpty() && entry.value("name").toString() == defaultName)
            return int(i);
        if (explicitRecommendation < 0 && (entry.value("recommended").toBool() ||
            legacyRecommendation.match(entry.value("description").toString()).hasMatch()))
            explicitRecommendation = int(i);
        const auto match = zimaVersion.match(entry.value("name").toString());
        if (match.hasMatch()) {
            const auto version = QVersionNumber::fromString(match.captured(1));
            if (latestStable < 0 || QVersionNumber::compare(version, latestVersion) > 0) {
                latestStable = int(i);
                latestVersion = version;
            }
        }
    }
    return explicitRecommendation >= 0 ? explicitRecommendation : latestStable;
}
}
#endif
