#!/bin/bash -xe

# A POSIX variable
OPTIND=1 # Reset in case getopts has been used previously in the shell.

while getopts "a:v:q:u:d:" opt; do
	case "$opt" in
	a)  ARCH=$OPTARG
		;;
	v)  VERSION=$OPTARG
		;;
	q)  QEMU_ARCH=$OPTARG
		;;
	u)  QEMU_VER=$OPTARG
		;;
	d)  DOCKER_REPO=$OPTARG
		;;
	esac
done

mysha256sum=sha256sum
if which gsha256sum &> /dev/null; then
	mysha256sum=gsha256sum
fi

(
rootTar="Fedora-Container-Root-${VERSION}.${ARCH}.tar"
baseUrl="https://download.fedoraproject.org/pub"
if wget --timeout=10 -4q --spider "$baseUrl/fedora-secondary/releases/${VERSION}/Container/${ARCH}/images"; then
	baseUrl+="/fedora-secondary/releases/${VERSION}/Container/${ARCH}/images"
elif wget --timeout=10 -4q --spider "$baseUrl/fedora/linux/releases/${VERSION}/Container/${ARCH}/images"; then
	baseUrl+="/fedora/linux/releases/${VERSION}/Container/${ARCH}/images"
else
	echo >&2 "error: Unable to find correct base url"
	exit 1
fi

for update in 5 4 3 2 1 0; do
	# 30-s390x only has the Minimal-Base image.
	for base in Base Minimal-Base; do
		if wget -4q --timeout=10 --spider "$baseUrl/Fedora-Container-${base}-${VERSION}-1.$update.${ARCH}.tar.xz"; then
			fullTar="Fedora-Container-${base}-${VERSION}-1.$update.${ARCH}.tar.xz"
			checksum="Fedora-Container-${VERSION}-1.$update-${ARCH}-CHECKSUM"
			break 2
		fi
	done
done

if [ -z "$fullTar" ]; then
	echo >&2 "error: Unable to find correct update"
	exit 1
fi

mkdir -p ../.temp/$fullTar.temp
pushd ../.temp
wget -4qN "$baseUrl/$checksum" || true
wget -4N "$baseUrl/$fullTar"
if [ -f $checksum ]; then
	# Set ignore-missing to Ignore Fedora-Container-Minimal-Base-*.tar.gz
	# in the checksum file.
	if ! $mysha256sum --status -c --ignore-missing $checksum; then
		echo >&2 "error: '$fullTar' has invalid SHA256"
		exit 1
	fi
fi
popd
tar -C ../.temp/$fullTar.temp -xf "../.temp/$fullTar"
mv -f ../.temp/$fullTar.temp/*/layer.tar $rootTar
rm -rf ../.temp/$fullTar.temp
cat > Dockerfile <<EOF
FROM scratch
ADD $rootTar /

ENV ARCH=${ARCH} FEDORA_SUITE=${VERSION} DOCKER_REPO=${DOCKER_REPO}
EOF

if [ -n "${QEMU_ARCH}" ]; then
	if [ ! -f x86_64_qemu-${QEMU_ARCH}-static.tar.gz ]; then
		wget -4N https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VER}/x86_64_qemu-${QEMU_ARCH}-static.tar.gz
	fi
	cat >> Dockerfile <<EOF

# Add qemu-user-static binary for amd64 builders
ADD x86_64_qemu-${QEMU_ARCH}-static.tar.gz /usr/bin
EOF
fi

cat >> Dockerfile <<EOF

# overwrite this with 'CMD []' in a dependent Dockerfile
CMD ["/bin/bash"]
EOF
)

docker build -t "${DOCKER_REPO}:${VERSION}-${ARCH}" .
docker run -it --rm "${DOCKER_REPO}:${VERSION}-${ARCH}" bash -xc '
	uname -a
	echo
	cat /etc/os-release 2>/dev/null
	echo
	cat /etc/redhat-release 2>/dev/null
	true
'
