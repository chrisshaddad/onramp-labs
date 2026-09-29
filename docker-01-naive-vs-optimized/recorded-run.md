# docker-01-naive-vs-optimized: recorded run

Recorded 2026-09-30 03:20 UTC with Docker Engine 29.1.2 (Docker Desktop 4.54.0 (212467)), client 29.8.1 by `scripts/verify.sh`.

The run is non-interactive: `verify.sh` makes the greeting edits with `sed` where the instructor edits `src/server.ts` in the editor, and runs `touch` directly where the run sheet uses a throwaway alpine container. Every other command is the run sheet's, plus `--progress=plain` on builds. Times in parentheses are wall-clock seconds.

## Before the session

### Reset

`03:20:02 UTC`  `sh /lab/docker-01-naive-vs-optimized/scripts/reset.sh`  (4.6 s)

```
docker-01 ready: lab images removed, greeting is v1, base images pulled.
```

## Run sheet

### 0. Shared kernel (optional), node:24-slim

`03:20:07 UTC`  `docker run --rm node:24-slim sh -c "uname -r; grep PRETTY_NAME /etc/os-release"`  (0.4 s)

```
6.18.33.2-microsoft-standard-WSL2
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
```

### 0. Shared kernel (optional), alpine:3

`03:20:08 UTC`  `docker run --rm alpine:3 sh -c "uname -r; grep PRETTY_NAME /etc/os-release"`  (0.4 s)

```
6.18.33.2-microsoft-standard-WSL2
PRETTY_NAME="Alpine Linux v3.24"
```

### 1. Naive build

`03:20:08 UTC`  `docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive .`  (33.9 s)

```
#0 building with "default" instance using docker driver

#1 [internal] load build definition from naive.Dockerfile
#1 transferring dockerfile: 274B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/node:24
#2 DONE 0.0s

#3 [1/5] FROM docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4
#3 resolve docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4 0.0s done
#3 DONE 0.1s

#4 [internal] load build context
#4 transferring context: 49.80kB 0.0s done
#4 DONE 0.1s

#5 [2/5] WORKDIR /app
#5 DONE 0.0s

#6 [3/5] COPY . .
#6 DONE 0.0s

#7 [4/5] RUN npm ci
#7 30.64 
#7 30.64 added 81 packages, and audited 82 packages in 30s
#7 30.64 
#7 30.64 28 packages are looking for funding
#7 30.64   run `npm fund` for details
#7 30.64 
#7 30.64 found 0 vulnerabilities
#7 30.64 npm notice
#7 30.64 npm notice New major version of npm available! 11.19.0 -> 12.1.0
#7 30.64 npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.1.0
#7 30.64 npm notice To update run: npm install -g npm@12.1.0
#7 30.64 npm notice
#7 DONE 30.8s

#8 [5/5] RUN npm run build
#8 0.260 
#8 0.260 > onramp-api@1.0.0 build
#8 0.260 > tsc
#8 0.260 
#8 DONE 0.4s

#9 exporting to image
#9 exporting layers
#9 exporting layers 1.5s done
#9 exporting manifest sha256:884605a9b2da55e6099342870c762cebde7fee8e2d59d7ecbdd2291902ed7f4b done
#9 exporting config sha256:c7279dff38085eb6425bdacc1ed0a567db49930a7f8288bac3a3195fd391c600 done
#9 exporting attestation manifest sha256:62d6bf92cf507706f641d55a2cdcafd95b147f6297ec0b73f1d749e0a720982a 0.0s done
#9 exporting manifest list sha256:8a5ff1d88eb5e7dd8ef5a4a8f3e2de8155a4dcc47f28218edaee167f731a7f46 0.0s done
#9 naming to docker.io/library/onramp-api:naive done
#9 unpacking to docker.io/library/onramp-api:naive
#9 unpacking to docker.io/library/onramp-api:naive 0.4s done
#9 DONE 2.0s
```

### 1. Image list

`03:20:42 UTC`  `docker image ls onramp-api`  (0.1 s)

```
IMAGE              ID             DISK USAGE   CONTENT SIZE   EXTRA
onramp-api:naive   8a5ff1d88eb5       1.71GB          433MB        
```

### 1. History

`03:20:42 UTC`  `docker history onramp-api:naive`  (0.0 s)

```
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
8a5ff1d88eb5   2 seconds ago    CMD ["node" "dist/server.js"]                   0B        buildkit.dockerfile.v0
<missing>      2 seconds ago    RUN /bin/sh -c npm run build # buildkit         49.2kB    buildkit.dockerfile.v0
<missing>      3 seconds ago    RUN /bin/sh -c npm ci # buildkit                55.6MB    buildkit.dockerfile.v0
<missing>      33 seconds ago   COPY . . # buildkit                             94.2kB    buildkit.dockerfile.v0
<missing>      33 seconds ago   WORKDIR /app                                    8.19kB    buildkit.dockerfile.v0
<missing>      11 days ago      CMD ["node"]                                    0B        buildkit.dockerfile.v0
<missing>      11 days ago      ENTRYPOINT ["docker-entrypoint.sh"]             0B        buildkit.dockerfile.v0
<missing>      11 days ago      COPY docker-entrypoint.sh /usr/local/bin/ # …   20.5kB    buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c set -ex   && export GNUPGHOME…   5.41MB    buildkit.dockerfile.v0
<missing>      11 days ago      ENV YARN_VERSION=1.22.22                        0B        buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c ARCH= && dpkgArch="$(dpkg --p…   217MB     buildkit.dockerfile.v0
<missing>      11 days ago      ENV NODE_VERSION=24.21.0                        0B        buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c groupadd --gid 1000 node   &&…   69.6kB    buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c set -ex;  apt-get update;  ap…   619MB     buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c set -eux;  apt-get update;  a…   194MB     buildkit.dockerfile.v0
<missing>      11 days ago      RUN /bin/sh -c set -eux;  apt-get update;  a…   52.3MB    buildkit.dockerfile.v0
<missing>      12 days ago      # debian.sh --arch 'amd64' out/ 'bookworm' '…   133MB     debuerreotype 0.17
```

2. Pause: (chat) which steps rerun after a one-line edit?

### 2. Touch the file, contents unchanged

`03:20:42 UTC`  `touch src/server.ts`  (0.0 s)

```
```

### 2. Rebuild naive after touch

`03:20:42 UTC`  `docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive .`  (0.8 s)

```
#0 building with "default" instance using docker driver

#1 [internal] load build definition from naive.Dockerfile
#1 transferring dockerfile: 274B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/node:24
#2 DONE 0.0s

#3 [1/5] FROM docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4
#3 resolve docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4 0.0s done
#3 DONE 0.0s

#4 [internal] load build context
#4 transferring context: 878B 0.0s done
#4 DONE 0.0s

#5 [2/5] WORKDIR /app
#5 CACHED

#6 [3/5] COPY . .
#6 CACHED

#7 [4/5] RUN npm ci
#7 CACHED

#8 [5/5] RUN npm run build
#8 CACHED

#9 exporting to image
#9 exporting layers done
#9 exporting manifest sha256:884605a9b2da55e6099342870c762cebde7fee8e2d59d7ecbdd2291902ed7f4b done
#9 exporting config sha256:c7279dff38085eb6425bdacc1ed0a567db49930a7f8288bac3a3195fd391c600 done
#9 exporting attestation manifest sha256:7d01cb994e364cfcae5fc8cc933692a6073f2a3729db0d4a759b89387209e312 0.0s done
#9 exporting manifest list sha256:2f810b98dbd718aaf1b5a4953510064091477b0c04b6c2109a360dba034f54df 0.0s done
#9 naming to docker.io/library/onramp-api:naive
#9 naming to docker.io/library/onramp-api:naive done
#9 unpacking to docker.io/library/onramp-api:naive 0.0s done
#9 DONE 0.1s
```

### 2. Edit src/server.ts: hello v1 -> hello v2

`03:20:43 UTC`  `sed -i 's/"hello v1"/"hello v2"/' src/server.ts`  (0.0 s)

```
```

### 2. Rebuild naive after the edit

`03:20:43 UTC`  `docker build --progress=plain -f naive.Dockerfile -t onramp-api:naive .`  (29.7 s)

```
#0 building with "default" instance using docker driver

#1 [internal] load build definition from naive.Dockerfile
#1 transferring dockerfile: 274B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/node:24
#2 DONE 0.0s

#3 [1/5] FROM docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4
#3 resolve docker.io/library/node:24@sha256:64af3819f9275802414d7cdc38c27e9d82bd564dec4d4da87d008255d36c63b4 0.0s done
#3 DONE 0.0s

#4 [internal] load build context
#4 transferring context: 878B 0.0s done
#4 DONE 0.0s

#5 [2/5] WORKDIR /app
#5 CACHED

#6 [3/5] COPY . .
#6 DONE 0.1s

#7 [4/5] RUN npm ci
#7 26.60 
#7 26.60 added 81 packages, and audited 82 packages in 26s
#7 26.60 
#7 26.60 28 packages are looking for funding
#7 26.60   run `npm fund` for details
#7 26.60 
#7 26.60 found 0 vulnerabilities
#7 26.60 npm notice
#7 26.60 npm notice New major version of npm available! 11.19.0 -> 12.1.0
#7 26.60 npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.1.0
#7 26.60 npm notice To update run: npm install -g npm@12.1.0
#7 26.60 npm notice
#7 DONE 26.7s

#8 [5/5] RUN npm run build
#8 0.310 
#8 0.310 > onramp-api@1.0.0 build
#8 0.310 > tsc
#8 0.310 
#8 DONE 0.4s

#9 exporting to image
#9 exporting layers
#9 exporting layers 1.4s done
#9 exporting manifest sha256:05ecdbe975ef3c84cca64670760426e0e6f1c0055743ec0c2814e34b052b241f done
#9 exporting config sha256:1890c8472f8079e599d01ed383e92e2d81760eabe380f3c8c592f234034d2cd0 0.0s done
#9 exporting attestation manifest sha256:676eb51cfc5d1bae97b74c6f7269a758e059410d85e2fe5f75f037df54f5c8ba 0.0s done
#9 exporting manifest list sha256:73653e4df1a000a64294cec5e715e8a1bd52d26b53f9daece2082822286ceb0d 0.0s done
#9 naming to docker.io/library/onramp-api:naive done
#9 unpacking to docker.io/library/onramp-api:naive
#9 unpacking to docker.io/library/onramp-api:naive 0.4s done
#9 DONE 1.9s
```

### 3. Optimized build

`03:21:13 UTC`  `docker build --progress=plain -t onramp-api:optimized .`  (14.1 s)

```
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 385B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/node:24-slim
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 92B 0.0s done
#3 DONE 0.0s

#4 [build 1/6] FROM docker.io/library/node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6
#4 resolve docker.io/library/node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 0.0s done
#4 DONE 0.0s

#5 [build 2/6] WORKDIR /app
#5 CACHED

#6 [internal] load build context
#6 transferring context: 251B 0.0s done
#6 DONE 0.0s

#7 [build 3/6] COPY package*.json ./
#7 DONE 0.1s

#8 [build 4/6] RUN npm ci
#8 11.11 
#8 11.11 added 81 packages, and audited 82 packages in 11s
#8 11.11 
#8 11.11 28 packages are looking for funding
#8 11.11   run `npm fund` for details
#8 11.11 
#8 11.11 found 0 vulnerabilities
#8 11.11 npm notice
#8 11.11 npm notice New major version of npm available! 11.19.0 -> 12.1.0
#8 11.11 npm notice Changelog: https://github.com/npm/cli/releases/tag/v12.1.0
#8 11.11 npm notice To update run: npm install -g npm@12.1.0
#8 11.11 npm notice
#8 DONE 11.2s

#9 [build 5/6] COPY . .
#9 DONE 0.0s

#10 [build 6/6] RUN npm run build && npm prune --omit=dev
#10 0.216 
#10 0.216 > onramp-api@1.0.0 build
#10 0.216 > tsc
#10 0.216 
#10 1.733 
#10 1.733 removed 13 packages, and audited 69 packages in 1s
#10 1.733 
#10 1.733 28 packages are looking for funding
#10 1.733   run `npm fund` for details
#10 1.734 
#10 1.734 found 0 vulnerabilities
#10 DONE 1.8s

#11 [stage-1 3/5] COPY --from=build /app/package.json ./
#11 DONE 0.0s

#12 [stage-1 4/5] COPY --from=build /app/node_modules ./node_modules
#12 DONE 0.1s

#13 [stage-1 5/5] COPY --from=build /app/dist ./dist
#13 DONE 0.0s

#14 exporting to image
#14 exporting layers 0.1s done
#14 exporting manifest sha256:8b60cd0fa17b3c64e82fd449ff54f0b01651b576683ca805446d1c0641bf99d6 done
#14 exporting config sha256:0f5ddf75f8002b4b56d2bef094d8c9ba7c8d0c5c46cf7aa38ad499fdf91224e3 done
#14 exporting attestation manifest sha256:85fd85f7eb1e56267dc7cb739f958bf535fefd9324399e596ef834b4e9ddda9f 0.0s done
#14 exporting manifest list sha256:2e695427d62b54eeb2b31ca41c187b7ae4687059b4ab1267621d956a4e178f34 done
#14 naming to docker.io/library/onramp-api:optimized done
#14 unpacking to docker.io/library/onramp-api:optimized 0.1s done
#14 DONE 0.3s
```

### 3. Edit src/server.ts: hello v2 -> hello v3

`03:21:27 UTC`  `sed -i 's/"hello v2"/"hello v3"/' src/server.ts`  (0.0 s)

```
```

### 3. Rebuild optimized after the edit

`03:21:27 UTC`  `docker build --progress=plain -t onramp-api:optimized .`  (3.0 s)

```
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 385B 0.0s done
#1 DONE 0.0s

#2 [internal] load metadata for docker.io/library/node:24-slim
#2 DONE 0.0s

#3 [internal] load .dockerignore
#3 transferring context: 92B 0.0s done
#3 DONE 0.0s

#4 [build 1/6] FROM docker.io/library/node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6
#4 resolve docker.io/library/node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 0.0s done
#4 DONE 0.0s

#5 [internal] load build context
#5 transferring context: 795B 0.0s done
#5 DONE 0.0s

#6 [build 2/6] WORKDIR /app
#6 CACHED

#7 [build 3/6] COPY package*.json ./
#7 CACHED

#8 [build 4/6] RUN npm ci
#8 CACHED

#9 [build 5/6] COPY . .
#9 DONE 0.0s

#10 [build 6/6] RUN npm run build && npm prune --omit=dev
#10 0.206 
#10 0.206 > onramp-api@1.0.0 build
#10 0.206 > tsc
#10 0.206 
#10 2.197 
#10 2.197 removed 13 packages, and audited 69 packages in 2s
#10 2.197 
#10 2.197 28 packages are looking for funding
#10 2.197   run `npm fund` for details
#10 2.198 
#10 2.198 found 0 vulnerabilities
#10 DONE 2.2s

#11 [stage-1 3/5] COPY --from=build /app/package.json ./
#11 CACHED

#12 [stage-1 4/5] COPY --from=build /app/node_modules ./node_modules
#12 CACHED

#13 [stage-1 5/5] COPY --from=build /app/dist ./dist
#13 DONE 0.0s

#14 exporting to image
#14 exporting layers 0.0s done
#14 exporting manifest sha256:af344cbfd6641ffeb302eaae7f02760f5ef428143d4baf8196c5c6f8d65232af done
#14 exporting config sha256:f730a18af8259d01de0a8aa1c8bc095717b551e617c187945f927b5cfe285f91 done
#14 exporting attestation manifest sha256:9d2906ae19c2bb5e7b3d20b21ee4cc086855080e4c6064c0dab2031b32f1aa21 0.0s done
#14 exporting manifest list sha256:2c098cf10c596705d4c49f3d05fd353045cbf54f1fb0273535e7dc92bb98f54f done
#14 naming to docker.io/library/onramp-api:optimized done
#14 unpacking to docker.io/library/onramp-api:optimized 0.0s done
#14 DONE 0.1s
```

### 4. Image list: sizes for the table

`03:21:30 UTC`  `docker image ls onramp-api`  (0.1 s)

```
IMAGE                  ID             DISK USAGE   CONTENT SIZE   EXTRA
onramp-api:naive       73653e4df1a0       1.71GB          433MB        
onramp-api:optimized   2c098cf10c59        335MB         81.5MB        
```

### 4. whoami, naive

`03:21:30 UTC`  `docker run --rm onramp-api:naive whoami`  (0.3 s)

```
root
```

### 4. whoami, optimized

`03:21:30 UTC`  `docker run --rm onramp-api:optimized whoami`  (0.3 s)

```
node
```

## Extra checks (not in the run sheet)

### Naive image: the whole folder was copied in

`03:21:31 UTC`  `docker run --rm onramp-api:naive ls -A /app`  (0.3 s)

```
.dockerignore
.reset-id
Dockerfile
dist
naive.Dockerfile
naive.Dockerfile.dockerignore
node_modules
package-lock.json
package.json
src
tsconfig.json
```

### Optimized build stage, built on its own

`03:21:31 UTC`  `docker build -q --target build -t onramp-api:build-stage .`  (2.4 s)

```
sha256:759c1fcc06aafe25913c98f52373bbd32585474fe3a82c3383f989411d920c12
```

### Optimized build stage: .dockerignore applied

`03:21:33 UTC`  `docker run --rm onramp-api:build-stage ls -A /app`  (0.4 s)

```
.dockerignore
.reset-id
Dockerfile
dist
node_modules
package-lock.json
package.json
src
tsconfig.json
```

### Run the optimized image

`03:21:34 UTC`  `docker run -d --name onramp-api-verify onramp-api:optimized`  (0.2 s)

```
a0e2d9c8b5fac59fb3e3ec7e73ffa2d5c254b194b5057135c90a3cc8599243e0
```

### Call it (slim has no curl or wget)

`03:21:34 UTC`  `docker exec onramp-api-verify node -e fetch('http://localhost:3000').then(r=>r.text()).then(console.log)`  (0.2 s)

```
{"greeting":"hello v3"}
```

### docker stop: SIGTERM, graceful shutdown

`03:21:35 UTC`  `docker stop onramp-api-verify`  (0.1 s)

```
onramp-api-verify
```

## After the session

### Reset

`03:21:35 UTC`  `sh /lab/docker-01-naive-vs-optimized/scripts/reset.sh`  (4.3 s)

```
docker-01 ready: lab images removed, greeting is v1, base images pulled.
```

## Numbers for the slide table

| | Naive | Optimized |
|---|---|---|
| Base image | node:24 | node:24-slim |
| Image size, DISK USAGE column | 1.71GB | 335MB |
| Image size, CONTENT SIZE column | 433MB | 81.5MB |
| Rebuild after a one-line edit | 29.7 s (npm ci 26.7s) | 3.0 s (npm ci CACHED) |
| whoami | root | node |

