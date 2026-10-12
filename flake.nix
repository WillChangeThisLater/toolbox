{
  description = "toolbox: paul's shell scripts, as derivations";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    # wrap a script so its PATH contains exactly the deps we declare
    mkScript = name: deps: pkgs.stdenv.mkDerivation {
      inherit name;
      src = ./.;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      installPhase = ''
        mkdir -p $out/bin
        install -Dm755 ${name}.sh $out/bin/${name}
        wrapProgram $out/bin/${name} --prefix PATH : ${pkgs.lib.makeBinPath deps}
      '';
    };
    convoDeps = with pkgs; [ llm tmux jq glow ];
  in {
    packages.x86_64-linux.convo = mkScript "convo" convoDeps;
    packages.x86_64-linux.default = self.packages.x86_64-linux.convo;
  };
}

{
  description = "shell scripts on shell scripts on shell scripts";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;

    mkScript = name: deps: pkgs.stdenv.mkDerivation {
      inherit name;
      src = ./.;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      installPhase = ''
        mkdir -p $out/bin
        install -Dm755 ${name}.sh $out/bin/${name}
        wrapProgram $out/bin/${name} --prefix PATH : ${pkgs.lib.makeBinPath deps}
      '';
    };
    convoDeps = with pkgs; [ llm tmux jq glow tmux ];
  in {
    packages.x86_64-linux.convo = mkScript "convo" convoDeps;
    packages.x86_64-linux.default = self.packages.x86_64-linux.convo;
  };
}
    
