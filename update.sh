#!/bin/bash -xe

mysha256sum=sha256sum
if which gsha256sum &> /dev/null; then
	mysha256sum=gsha256sum
fi

cd "$(dirname "$BASH_SOURCE")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

repo="$(cat repo 2>/dev/null || true)"
if [ -z "$repo" ]; then
	user="$(docker info | awk -F ': ' '$1 == "Username" { print $2; exit }')"
	repo="${user:+$user/}fedora"
fi

for version in "${versions[@]}"; do
	(
	cd "$version"
	v="$(cat version)"
	arch="$(cat arch)"
	qemu_arch="$(cat qemu_arch 2>/dev/null || true)"
	rootTar="Fedora-Container-Root-$v.$arch.tar"
	baseUrl="https://download.fedoraproject.org/pub"
	if wget --timeout=10 -4q --spider "$baseUrl/fedora-secondary/releases/$v/Container/$arch/images"; then
		baseUrl+="/fedora-secondary/releases/$v/Container/$arch/images"
	elif wget --timeout=10 -4q --spider "$baseUrl/fedora/linux/releases/$v/Container/$arch/images"; then
		baseUrl+="/fedora/linux/releases/$v/Container/$arch/images"
	else
		echo >&2 "error: Unable to find correct base url"
		exit 1
	fi
	
	for update in 5 4 3 2 1 0; do
		# 30-s390x only has the Minimal-Base image.
		for base in Base Minimal-Base; do
			if wget -4q --timeout=10 --spider "$baseUrl/Fedora-Container-${base}-$v-1.$update.$arch.tar.xz"; then
				fullTar="Fedora-Container-${base}-$v-1.$update.$arch.tar.xz"
				checksum="Fedora-Container-$v-1.$update-$arch-CHECKSUM"
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

ENV ARCH=${arch} FEDORA_SUITE=${v} DOCKER_REPO=${repo}
EOF

	if [ -n "${qemu_arch}" ]; then
		if [ ! -f x86_64_qemu-${qemu_arch}-static.tar.gz ]; then
			wget -4N https://github.com/multiarch/qemu-user-static/releases/download/v3.1.0-3/x86_64_qemu-${qemu_arch}-static.tar.gz
		fi
		cat >> Dockerfile <<EOF

# Add qemu-user-static binary for amd64 builders
ADD x86_64_qemu-${qemu_arch}-static.tar.gz /usr/bin
EOF
	fi

cat >> Dockerfile <<EOF

# overwrite this with 'CMD []' in a dependent Dockerfile
CMD ["/bin/bash"]
EOF
	)
done

for v in "${versions[@]}"; do
	if [ ! -f "$v/Dockerfile" ]; then
		echo >&2 "warning: $v/Dockerfile does not exist; skipping $v"
		continue
	fi
	( set -x; docker build -t "$repo:$v" "$v" )
	docker run -it --rm "$repo:$v" bash -xc '
		uname -a
		echo
		cat /etc/os-release 2>/dev/null
		echo
		cat /etc/redhat-release 2>/dev/null
		true
	'
	if [ -s "$v/alias" ]; then
		for a in $(< "$v/alias"); do
			( set -x; docker tag -f "$repo:$v" "$repo:$a" )
		done
	fi
done
