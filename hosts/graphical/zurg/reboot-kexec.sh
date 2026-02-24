cmdline="init=$(readlink -f /nix/var/nix/profiles/system/init) $(cat /nix/var/nix/profiles/system/kernel-params)"
kexec -l /nix/var/nix/profiles/system/kernel --initrd=/nix/var/nix/profiles/system/initrd --command-line="$cmdline"
systemctl kexec
