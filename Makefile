all: build_custom_arch_iso_with_podman

build_custom_arch_iso_with_podman:
	podman build -t archlinux_pull_modify_iso .
	podman run --privileged --name=builder_archiso archlinux_pull_modify_iso
	podman cp builder_archiso:/tmp/archiso_custom/out ./
	podman rm -f builder_archiso
	podman rmi -f archlinux_pull_modify_iso

build_custom_arch_iso_with_podman_debug:
	podman build -t archlinux_pull_modify_iso .
	podman run --privileged -it --name=builder_archiso archlinux_pull_modify_iso bash
	podman cp builder_archiso:/tmp/archiso_custom/out ./
	podman rm -f builder_archiso
	podman rmi -f archlinux_pull_modify_iso