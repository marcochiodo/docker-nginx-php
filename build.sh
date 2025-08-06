#!/usr/bin/bash

if test "${1}" = "83";
then
    docker buildx build --build-arg V=83 --build-arg ALPINE_VERSION=3.20 -t sigblue/nginx-php:83 --no-cache .
elif test "${1}" = "84";
then
    docker buildx build --build-arg V=84 --build-arg ALPINE_VERSION=3.21 -t sigblue/nginx-php:84 --no-cache .
else
    echo "Error: PHP version not valid";
    exit 2;
fi
