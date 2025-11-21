FROM alpine

# Устанавливаем необходимые утилиты
RUN apk add --no-cache ca-certificates curl tar

WORKDIR /app

# Загружаем и распаковываем precompiled бинарник dnscrypt-proxy (укажите нужную версию)
COPY dnscrypt-proxy .


# Копируем конфигурацию в образ
COPY dnscrypt-proxy.toml .


EXPOSE 53/tcp 53/udp

CMD ["./dnscrypt-proxy", "-config", "dnscrypt-proxy.toml"]
