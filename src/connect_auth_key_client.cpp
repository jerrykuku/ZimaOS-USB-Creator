/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (C) 2026 Raspberry Pi Ltd
 */

#include "connect_auth_key_client.h"
#include "curlnetworkconfig.h"

#include <QByteArray>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QUrl>
#include <QUrlQuery>

#include <curl/curl.h>

namespace {

constexpr const char *DEFAULT_CONNECT_BASE_URL =
    "https://api.connect.raspberrypi.com";

size_t curlWriteToByteArray(char *ptr, size_t size, size_t nmemb, void *userdata)
{
    auto *out = static_cast<QByteArray *>(userdata);
    const size_t byteCount = size * nmemb;
    out->append(ptr, static_cast<int>(byteCount));
    return byteCount;
}

} // namespace

ConnectAuthKeyClient::ConnectAuthKeyClient(const QString &apiKey,
                                           const QString &baseUrl)
    : _apiKey(apiKey.trimmed())
    , _baseUrl(baseUrl.isEmpty() ? QString::fromLatin1(DEFAULT_CONNECT_BASE_URL)
                                 : baseUrl)
{
}

ConnectAuthKeyClient::Result ConnectAuthKeyClient::requestAuthKey(
    const QString &description,
    int ttlDays) const
{
    Result result;
    if (_apiKey.isEmpty()) {
        result.errorMessage = QStringLiteral("Connect API key not configured");
        return result;
    }

    const QString url = _baseUrl + QStringLiteral("/organisation/auth-keys");
    QUrlQuery form;
    form.addQueryItem(QStringLiteral("description"), description);
    if (ttlDays > 0)
        form.addQueryItem(QStringLiteral("ttl_days"), QString::number(ttlDays));
    const QByteArray body = form.toString(QUrl::FullyEncoded).toUtf8();

    qDebug() << "Connect: POSTing auth-key request to" << url;

    CURL *curl = curl_easy_init();
    if (!curl) {
        result.errorMessage = QStringLiteral("curl_easy_init failed");
        return result;
    }

    CurlNetworkConfig::instance().applyCurlSettings(
        curl, CurlNetworkConfig::FetchProfile::FireAndForget);

    QByteArray responseBody;
    struct curl_slist *headers = nullptr;
    const QByteArray authHeader =
        QByteArrayLiteral("Authorization: Bearer ") + _apiKey.toUtf8();
    headers = curl_slist_append(headers, authHeader.constData());
    headers = curl_slist_append(
        headers, "Content-Type: application/x-www-form-urlencoded");

    const QByteArray urlUtf8 = url.toUtf8();
    curl_easy_setopt(curl, CURLOPT_URL, urlUtf8.constData());
    curl_easy_setopt(curl, CURLOPT_POST, 1L);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.constData());
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curlWriteToByteArray);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &responseBody);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);

    char errorBuffer[CURL_ERROR_SIZE] = {};
    curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errorBuffer);

    long httpCode = 0;
    const CURLcode curlResult = curl_easy_perform(curl);
    if (curlResult != CURLE_OK) {
        result.errorMessage = QStringLiteral("Network error: %1")
            .arg(QString::fromLatin1(errorBuffer[0]
                ? errorBuffer
                : curl_easy_strerror(curlResult)));
    } else {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &httpCode);
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (!result.errorMessage.isEmpty())
        return result;

    QJsonParseError jsonError{};
    const QJsonDocument response = QJsonDocument::fromJson(responseBody, &jsonError);
    const QJsonObject object = response.isObject() ? response.object() : QJsonObject{};

    if (httpCode != 201) {
        const QString serverMessage = object.value(QStringLiteral("message")).toString();
        if (httpCode == 401) {
            result.errorMessage = QStringLiteral(
                "Raspberry Pi Connect rejected the organisation API key (HTTP 401). "
                "Check the key in App Options.");
        } else if (httpCode == 422 && !serverMessage.isEmpty()) {
            result.errorMessage = serverMessage;
        } else {
            const QString detail = serverMessage.isEmpty()
                ? QString::fromUtf8(responseBody)
                : serverMessage;
            result.errorMessage = QStringLiteral(
                "Connect API auth-key request failed (HTTP %1): %2")
                .arg(httpCode).arg(detail);
        }
        return result;
    }

    if (!response.isObject()) {
        result.errorMessage = QStringLiteral("Connect API returned non-object body: %1")
            .arg(QString::fromUtf8(responseBody));
        return result;
    }

    result.id = object.value(QStringLiteral("id")).toString();
    result.secret = object.value(QStringLiteral("secret")).toString();
    if (result.secret.isEmpty()) {
        result.errorMessage = QStringLiteral(
            "Connect API response missing 'secret' field");
        return result;
    }

    qDebug().noquote() << "Connect: minted auth-key id=" << result.id
                       << "expires_at="
                       << object.value(QStringLiteral("expires_at")).toString();
    result.ok = true;
    return result;
}
