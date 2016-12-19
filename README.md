# :earth_africa: fedora

![](https://raw.githubusercontent.com/multiarch/dockerfile/master/logo.jpg)

Multiarch Fedora images for Docker.

* `multiarch/fedora` on [Docker Hub](https://hub.docker.com/r/multiarch/fedora/)
* [Available tags](https://hub.docker.com/r/multiarch/fedora/tags/)

## Usage

Once you need to configure binfmt-support on your Docker host.
This works locally or remotely (i.e using boot2docker or swarm).

```console
# configure binfmt-support on the Docker host (works locally or remotely, i.e: using boot2docker)
$ docker run --rm --privileged multiarch/qemu-user-static:register --reset
```

Then you can run an `armhfp` image from your `x86_64` Docker host.

```console
$ docker run -it --rm multiarch/fedora:25-armhfp
root@90440a11f34d:/# uname -a
Linux 90440a11f34d 4.4.27-moby #1 SMP Wed Oct 26 14:21:29 UTC 2016 armv7l armv7l armv7l GNU/Linux
root@90440a11f34d:/# exit
```

Or an `x86_64` image from your `x86_64` Docker host, directly, without qemu emulation.

```console
$ docker run -it --rm multiarch/fedora:25-x86_64
root@44f11f2bc4a8:/# uname -a
Linux 44f11f2bc4a8 4.4.27-moby #1 SMP Wed Oct 26 14:21:29 UTC 2016 x86_64 x86_64 x86_64 GNU/Linux
root@44f11f2bc4a8:/#
```

It also works for `aarch64`

```console
$ docker run -it --rm multiarch/fedora:25-aarch64
root@34f68c7ec9ae:/# uname -a
Linux 34f68c7ec9ae 4.4.27-moby #1 SMP Wed Oct 26 14:21:29 UTC 2016 aarch64 aarch64 aarch64 GNU/Linux
root@34f68c7ec9ae:/#
```

## License

MIT
