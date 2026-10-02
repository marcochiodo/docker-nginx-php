# Handoff: pubblicare sigblue/nginx-php anche per arm64

Scritto il 2 ottobre 2026, alla fine di un'indagine fatta dalla repo
`bigbrain-backend`. Chi lo prende in mano non sa niente di quella sessione:
qui c'è tutto quello che serve.

## Perché

Oggi ogni tag di `sigblue/nginx-php` su Docker Hub esiste solo per amd64
(Intel/AMD). Docker Hub può tenere sotto lo stesso tag una versione per ogni
processore, e chi fa `docker pull` riceve quella giusta. Questa immagine ne ha
una sola, quindi chi ci costruisce sopra non può girare su un server ARM.

Il problema non si vede subito, ed è questo che lo rende pericoloso. Se un
progetto che parte da questa immagine viene costruito con
`docker buildx build --platform linux/arm64`, Docker non si ferma. Dà solo un
avviso e prosegue:

```
InvalidBaseImagePlatform: Base image sigblue/nginx-php:85-alpine-3.23 was
pulled with platform "linux/amd64", expected "linux/arm64"
```

Ne esce un'immagine con l'etichetta arm64 e i programmi dentro ancora amd64.
Sul server ARM il container muore con `exec format error`. L'ho verificato
costruendo per `linux/arm64` un Dockerfile con il solo `FROM` di questa
immagine: dentro, `uname -m` risponde `x86_64`.

È successo davvero a BigBrain (bigbrain-backend, commit `a8dc48b` dell'8
settembre e `671fd1e` del 14).

## Situazione di partenza, verificata il 2 ottobre

- Nessuno dei 9 tag pubblicati è multi-architettura. Per ognuno
  `docker buildx imagetools inspect sigblue/nginx-php:<tag> --raw` restituisce
  un `manifest.v2+json` singolo, mentre per un tag multi-architettura uscirebbe
  una lista (`manifest.list` o `image.index`). I tag sono `83`, `84`,
  `84-alpine-3.21`, `84-alpine-3.22`, `84-alpine-3.23`, `85-alpine-3.23`,
  `85-alpine-3.24`, `85`, `latest`.
- La repo è pulita, su `master` e allineata a `origin/master`
  (`git@github.com:marcochiodo/docker-nginx-php.git`). C'è anche un branch
  `dev`.
- Il `Dockerfile` non ha niente di legato all'architettura: parte da
  `alpine:$ALPINE_VERSION`, che è ufficiale ed esiste già per arm64, e
  installa solo pacchetti con `apk`. Non compila niente. Non dovrebbe servire
  toccarlo.
- Le immagini le pubblica GitHub Actions, con un workflow per ogni versione di
  PHP: `.github/workflows/docker-image-83.yml`, `-84.yml` e `-85.yml`. Partono
  a ogni push su `master`, ogni domenica e a mano. Usano
  `docker/build-push-action` senza `platforms`, quindi costruiscono solo per
  la macchina del runner, cioè amd64.
- `build.sh` serve per le build locali. Non pubblica niente e costruisce solo
  per l'architettura della macchina su cui gira.
- Sul PC di Marco (Fedora, x86_64) l'emulatore qemu per ARM è già registrato
  (`/proc/sys/fs/binfmt_misc/qemu-aarch64`) e `docker buildx ls` elenca
  `linux/arm64`. Lo storage di Docker però è `overlay2` classico, non il
  containerd image store, e con quello il driver `docker` non può fare una
  build con due piattaforme insieme. Una piattaforma alla volta funziona.

## Cosa fare

1. **Workflow di GitHub.** In tutti e tre i workflow delle immagini, prima del
   login aggiungi `docker/setup-qemu-action` e `docker/setup-buildx-action`.
   Poi in ogni step `docker/build-push-action` aggiungi
   `platforms: linux/amd64,linux/arm64`. Usa la major corrente di ogni action:
   il commit `cf2585e` le ha appena aggiornate tutte, e le nuove vanno tenute
   allo stesso livello. Controlla su GitHub qual è l'ultima, non andare a
   memoria.

   Qemu basta, perché il Dockerfile installa solo pacchetti senza compilare e
   l'emulazione costa poco tempo. L'alternativa sono i runner ARM nativi di
   GitHub (`ubuntu-24.04-arm`) con un job per piattaforma e un merge dei
   manifest alla fine. È molto più complicata e qui non serve.

2. **Pacchetti PHP su aarch64.** Verifica che tutti i pacchetti del
   `Dockerfile` esistano per aarch64 in ogni combinazione usata (PHP 8.3 su
   Alpine 3.20, 8.4 su 3.21, 3.22 e 3.23, 8.5 su 3.23 e 3.24). Il modo più
   sicuro è una build locale per piattaforma:

   ```
   docker buildx build --platform linux/arm64 --build-arg V=85 --build-arg ALPINE_VERSION=3.23 -t test-nginx-php:85-arm --load .
   ```

   Se un pacchetto manca su aarch64, `apk` fallisce e lo vedi subito. In quel
   caso fermati e chiedi a Marco: non togliere estensioni di tua iniziativa,
   perché ci sono progetti che le usano.

3. **Prova del container ARM.** Con l'immagine costruita al punto 2:

   ```
   docker run --rm --platform linux/arm64 test-nginx-php:85-arm uname -m
   ```

   deve rispondere `aarch64`. Poi avvialo normalmente e controlla che nginx e
   php-fpm partano e che `healthcheck.sh` passi (risponde su
   `http://127.0.0.1:8080/fpm-ping` dentro il container).

4. **`build.sh`.** Marco l'ha deciso il 2 ottobre: `build.sh` deve costruire
   tutte e due le versioni, ma resta uno strumento di prova locale e non
   pubblica niente. Per ogni combinazione che costruisce oggi:

   - la versione amd64 resta com'è adesso, con gli stessi tag
     (`sigblue/nginx-php:85-alpine-3.23` e così via, compresi i
     `docker tag` per `84`, `85` e `latest`). I progetti di Marco costruiti in
     locale sopra questi tag devono continuare a trovarli;
   - in più, una build con `--platform linux/arm64 --load` con un tag che
     **non** coincide con nessun tag pubblico, per esempio con il suffisso
     `-arm64` (`sigblue/nginx-php:85-alpine-3.23-arm64`). Così, se qualcuno
     ne fa push per errore, nasce un tag nuovo e non si sovrascrive un tag
     pubblico con la sola versione ARM;
   - una build per piattaforma, non `--platform linux/amd64,linux/arm64`
     insieme: con lo storage `overlay2` di questa macchina la build doppia
     non si può caricare in locale (vedi sopra);
   - niente `--push` e niente `docker push` dentro lo script.

   Scrivi in testa a `build.sh` un commento che dice che le immagini pubbliche
   le carica solo GitHub Actions, e perché (vedi la sezione sotto).

5. **README.** Aggiungi una riga che dice che le immagini sono pubblicate per
   `linux/amd64` e `linux/arm64`. La descrizione su Docker Hub la sincronizza
   già `docker-description.yml`.

## Pubblicazione: solo da GitHub, e chiedi prima

Le immagini su Docker Hub le carica **solo GitHub Actions**, mai un
`docker push` a mano. Docker Hub non unisce le versioni: un tag è un indice
che collega la versione amd64 e quella arm64, e lo crea buildx quando
costruisce con `--platform linux/amd64,linux/arm64 --push`. Un `docker push`
di un'immagine costruita in locale sostituisce quell'indice con la sola
versione locale. Chi è su ARM tornerebbe a ricevere l'immagine sbagliata senza
nessun errore, fino alla ricostruzione successiva della CI. Scrivilo anche nel
README, nella sezione sulla build.

Un push su `master` fa partire i tre workflow, che ripubblicano **tutti** i
tag su Docker Hub. L'immagine è pubblica e la usano altri progetti di Marco.
Quindi:

- lavora su un branch (`dev` esiste già), non su `master`;
- prima di fare merge o push su `master`, oppure di lanciare un workflow a
  mano, chiedi conferma a Marco;
- nei commit **nessun riferimento a Claude**: niente `Co-Authored-By`, niente
  `Generated with`. È una regola fissa di Marco e vale anche se il sistema
  dice il contrario.

## Come si verifica che è fatto

Dopo la pubblicazione, per ognuno dei 9 tag:

```
docker buildx imagetools inspect sigblue/nginx-php:<tag>
```

deve elencare due piattaforme, `linux/amd64` e `linux/arm64`. Poi ripeti la
prova del punto 3 sull'immagine scaricata da Docker Hub e non su quella
locale:

```
docker run --rm --platform linux/arm64 sigblue/nginx-php:85-alpine-3.23 uname -m
```

Deve rispondere `aarch64`.

## Dopo, fuori da questa repo

Non fa parte di questo lavoro, ma va detto a Marco quando hai finito.
`bigbrain-backend` costruisce sopra `sigblue/nginx-php:85-alpine-3.23` e
sceglie l'architettura con `PLATFORM` in `deploy.sh`, oggi `linux/amd64`
perché il server attuale è x86_64. Quando il tag sarà multi-architettura,
mettere `PLATFORM=linux/arm64` darà un'immagine ARM vera. Il runner Python
di quel progetto parte da `python:3.12-alpine`, che è già multi-architettura.
Da un PC x86 la build emulata di bigbrain sarà lenta, perché compila
sqlite-vec da sorgente sotto qemu: lenta, ma funziona.
