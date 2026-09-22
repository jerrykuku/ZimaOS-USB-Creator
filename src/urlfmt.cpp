#include "urlfmt.h"

QString UrlFmt::display(const QUrl &u) const {
    return u.toString(QUrl::PreferLocalFile | QUrl::NormalizePathSegments);
}

QUrl UrlFmt::fromLocalFile(const QString &path) const {
    return QUrl::fromLocalFile(path);
}
