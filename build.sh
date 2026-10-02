#!/usr/bin/bash

# Le immagini pubbliche su Docker Hub le carica SOLO GitHub Actions, mai questo
# script e mai un `docker push` a mano. Docker Hub non unisce le versioni: un
# tag e' un indice che collega la versione amd64 e quella arm64, e lo crea
# buildx solo quando costruisce con `--platform linux/amd64,linux/arm64 --push`.
# Un push a mano di un'immagine costruita in locale sostituirebbe quell'indice
# con la sola versione locale, e chi e' su ARM tornerebbe a ricevere l'immagine
# sbagliata senza nessun errore. Qui si costruisce solo in locale per provare.

if test "${1}" = "83";
then
    docker buildx build --build-arg V=83 --build-arg ALPINE_VERSION=3.20 -t sigblue/nginx-php:83 --no-cache .
    docker buildx build --platform linux/arm64 --build-arg V=83 --build-arg ALPINE_VERSION=3.20 -t sigblue/nginx-php:83-arm64 --no-cache --load .
elif test "${1}" = "84";
then
    docker buildx build --build-arg V=84 --build-arg ALPINE_VERSION=3.21 -t sigblue/nginx-php:84-alpine-3.21 --no-cache .
    docker tag sigblue/nginx-php:84-alpine-3.21 sigblue/nginx-php:84
    docker buildx build --build-arg V=84 --build-arg ALPINE_VERSION=3.22 -t sigblue/nginx-php:84-alpine-3.22 --no-cache .
    docker buildx build --build-arg V=84 --build-arg ALPINE_VERSION=3.23 -t sigblue/nginx-php:84-alpine-3.23 --no-cache .
    docker buildx build --platform linux/arm64 --build-arg V=84 --build-arg ALPINE_VERSION=3.21 -t sigblue/nginx-php:84-alpine-3.21-arm64 --no-cache --load .
    docker buildx build --platform linux/arm64 --build-arg V=84 --build-arg ALPINE_VERSION=3.22 -t sigblue/nginx-php:84-alpine-3.22-arm64 --no-cache --load .
    docker buildx build --platform linux/arm64 --build-arg V=84 --build-arg ALPINE_VERSION=3.23 -t sigblue/nginx-php:84-alpine-3.23-arm64 --no-cache --load .
elif test "${1}" = "85";
then
    docker buildx build --build-arg V=85 --build-arg ALPINE_VERSION=3.23 -t sigblue/nginx-php:85-alpine-3.23 --no-cache .
    docker buildx build --build-arg V=85 --build-arg ALPINE_VERSION=3.24 -t sigblue/nginx-php:85-alpine-3.24 --no-cache .
    docker tag sigblue/nginx-php:85-alpine-3.24 sigblue/nginx-php:85
    docker tag sigblue/nginx-php:85-alpine-3.24 sigblue/nginx-php:latest
    docker buildx build --platform linux/arm64 --build-arg V=85 --build-arg ALPINE_VERSION=3.23 -t sigblue/nginx-php:85-alpine-3.23-arm64 --no-cache --load .
    docker buildx build --platform linux/arm64 --build-arg V=85 --build-arg ALPINE_VERSION=3.24 -t sigblue/nginx-php:85-alpine-3.24-arm64 --no-cache --load .

else
    echo "Error: PHP version not valid";
    exit 2;
fi
