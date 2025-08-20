# crossbuild
:earth_africa: multiarch cross compiling environments

This is a multiarch Docker build environment image.
You can use this image to produce binaries for multiple architectures.

## Supported targets

| Triple                                        | Aliases                             | linux   | freebsd |
|-----------------------------------------------|-------------------------------------|---------|---------|
| x86_64-linux-gnu, x86_64-linux-musl           | **(default)**, linux, amd64, x86_64 | ✔       |         |
| arm-linux-gnueabihf, arm-linux-musleabihf     | armhf, armv7, armv7l                | ✔       |         |
| aarch64-linux-gnu, aarch64-linux-musl         | arm64, aarch64                      | ✔       |         |
| x86_64-pc-freebsd14                           | freebsd                             |         | ✔       |

## Using crossbuild

#### x86_64

```console
$ docker run --rm -v $(pwd):/workdir authelia/crossbuild make helloworld
cc helloworld.c -o helloworld
$ file helloworld
helloworld: ELF 64-bit LSB  executable, x86-64, version 1 (SYSV), dynamically linked (uses shared libs), for GNU/Linux 2.6.32, BuildID[sha1]=9cfb3d5b46cba98c5aa99db67398afbebb270cb9, not stripped
```

Misc: using `cc` instead of `make`

```console
$ docker run --rm -v $(pwd):/workdir authelia/crossbuild cc test/helloworld.c
```

#### armhf

```console
$ docker run --rm -v $(pwd):/workdir -e CROSS_TRIPLE=arm-linux-gnueabihf authelia/crossbuild make helloworld
```

#### arm64

```console
$ docker run --rm -v $(pwd):/workdir -e CROSS_TRIPLE=aarch64-linux-gnu authelia/crossbuild make helloworld
```

#### freebsd x86_64

```console
$ docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=x86_64-pc-freebsd14  authelia/crossbuild make helloworld
```

## Credit

This project is inspired by the [cross-compiler](https://github.com/steeve/cross-compiler) by the venerable [Steeve Morin](https://github.com/steeve)

## License

MIT
