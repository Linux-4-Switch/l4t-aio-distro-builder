#!/bin/bash
set -e

# If we're inside docker we get the volume name attached to the running container otherwise retrieve the output directory inputed
if  [[ -f /.dockerenv ]]; then out=/out; volume=$(docker inspect -f '{{range .Mounts}}{{.Name}}{{end}}' "$(cat /etc/hostname)");
	else out="$(realpath "${@:$#}")"; volume="${out}"; [[ ! -d ${out} ]] && echo "Invalid output path: ${out}" && exit 1; fi

# Check if the environement variables are set
[[ -z "${DISTRO}" || -z "${PARTNUM}" || -z "${DEVICE}" ]] && \
	echo "Invalid options: DISTRO=${DISTRO} PARTNUM=${PARTNUM} DEVICE=${DEVICE}" && exit 1

# Check if docker is installed
[[ ! $(command -v docker) ]] && \
	echo "Docker is not installed on your machine..." && exit 1

# Check if 7zip is installed
if [[ $(command -v 7z) ]]; then zip_ver=7z;
	elif [[ $(command -v 7za) ]]; then zip_ver=7za;
	else [[ -z "${zip_ver}" ]] && \
	echo "7z is not installed on your machine..." && exit 1; fi

set +e
rm -rf "${out}/Image" "${out}/tegra210-icosa.dtb" "${out}/modules.tar.gz" "${out}/update.tar.gz" "${out}/switchroot/${DISTRO}" "${out}/bootloader/"
set -e

echo -e "\n\t\tBuilding boot.scr and initramfs and updating coreboot.rom\n"
docker run -it --rm -e CPUS="${CPUS}" -e DISTRO="${DISTRO}" -e PARTNUM="${PARTNUM}" -v "${volume}":/out alizkan/l4t-bootfiles-misc:latest

echo -e "\n\t\tBuilding L4T-Kernel\n"
docker run -it --rm -e CPUS="${CPUS}" -v "${volume}":/out alizkan/l4t-kernel:latest

# Copying kernel, kernel modules and device tree file to switchroot directrory
mv "${out}/Image" "${out}/tegra210-icosa.dtb" "${out}/modules.tar.gz" "${out}/update.tar.gz" "${out}/switchroot/${DISTRO}"

echo -e "\n\t\tBuilding the actual distribution\n"
docker run -it --rm --privileged -e DISTRO="${DISTRO}" -e DEVICE="${DEVICE}" -e HEKATE=true -v "${volume}":/out alizkan/jet-factory:latest

echo -e "\n\t\tUpdating and renaming 7z archive created during JetFactory build\n"
"${zip_ver}" u "${out}/switchroot-${DISTRO}.7z" "${out}/bootloader" "${out}/switchroot"

# Add date for release tag.
mv "${out}/switchroot-${DISTRO}.7z" "${out}/switchroot-${DISTRO}-$(date +%F).7z"

# Cleaning build files
rm -r "${out}/bootloader/" "${out}/switchroot/"
echo -e "\n\t\tDone, file produced: switchroot-${DISTRO}-$(date +%F).7z\n"
