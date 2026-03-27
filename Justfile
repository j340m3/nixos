set export

export SOPS_AGE_KEY := `rbw get age-key-nixos | xargs`
export AGE_PUBLIC_KEY := `rbw get age-key-nixos --field=username | xargs`

snano path: 
    sops edit $path

sops-refresh:
    sops refresh 