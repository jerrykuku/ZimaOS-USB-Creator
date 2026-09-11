/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 Raspberry Pi Ltd
 */

#ifndef CONNECT_AUTH_KEY_CLIENT_H
#define CONNECT_AUTH_KEY_CLIENT_H

#include <QString>

class ConnectAuthKeyClient
{
public:
    struct Result {
        bool ok = false;
        QString id;
        QString secret;
        QString errorMessage;
    };

    explicit ConnectAuthKeyClient(const QString &apiKey,
                                  const QString &baseUrl = QString());

    Result requestAuthKey(const QString &description, int ttlDays = 1) const;

private:
    QString _apiKey;
    QString _baseUrl;
};

#endif // CONNECT_AUTH_KEY_CLIENT_H
