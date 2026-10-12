{
  description = "toolbox: paul's shell scripts, as derivations";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    lib = pkgs.lib;

    # fallback deps for scripts without a specific entry
    commonDeps = with pkgs; [ coreutils gnugrep tmux jq curl ];

    # per-script dependency map (name without .sh)
    scriptDeps = {
      add_cluster = with pkgs; [ awscli2 fzf jq ];
      addrs = with pkgs; [ jq ];
      agent = [ ]; # uses ambient/dev pi on purpose (see toolbox notes)
      a = with pkgs; [ gnome-screenshot llm ];
      bash-agent = with pkgs; [ jq llm uv ];
      bconvo = with pkgs; [ jq ];
      bf = with pkgs; [ awscli2 tmux ];
      bllm = with pkgs; [ codex curl git jq llm tmux ];
      capture = with pkgs; [ tmux ];
      codex-search = with pkgs; [ jq ];
      convo = with pkgs; [ llm tmux jq glow ];
      convo-pane = with pkgs; [ tmux ];
      current-pane = with pkgs; [ tmux ];
      debug = with pkgs; [ tmux ];
      dockertmp = with pkgs; [ docker ];
      download-site = with pkgs; [ imagemagick wget ];
      ecr-push = with pkgs; [ awscli2 docker ];
      env-gen = with pkgs; [ awscli2 jq ];
      find-panes = with pkgs; [ llm python3 tmux ];
      gallery = with pkgs; [ imagemagick ];
      getarg = with pkgs; [ jq llm nodejs ];
      markdown = with pkgs; [ awscli2 ];
      okta = with pkgs; [ awscli2 jq ];
      pbcopy = with pkgs; [ xclip wl-clipboard ];
      pbpaste = with pkgs; [ xclip wl-clipboard ];
      p = with pkgs; [ llm ];
      qq = with pkgs; [ llm ];
      remote-setup = with pkgs; [ curl wget docker ];
      set_key_repeat = with pkgs; [ glib ];
      share = with pkgs; [ curl ];
      shot = with pkgs; [ gnome-screenshot ];
      slink = with pkgs; [ openssh ];
      smuggle = with pkgs; [ docker ];
      tmpopen = with pkgs; [ awscli2 ];
      tmux-prompt = with pkgs; [ llm tmux ];
      transcribe = with pkgs; [ llm ];
      tscreen = with pkgs; [ jq llm tmux ];
      utils = with pkgs; [ docker ];
      uv-header = with pkgs; [ ffmpeg uv ];
      youtube_dl = with pkgs; [ jq yt-dlp ];
    };

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

    scriptNames = builtins.filter (n: lib.hasSuffix ".sh" n)
      (builtins.attrNames (builtins.readDir ./.));
    packages = lib.listToAttrs (map (s:
      let n = lib.removeSuffix ".sh" s; in
      lib.nameValuePair n (mkScript n (scriptDeps.${n} or commonDeps))
    ) scriptNames);
  in {
    packages.x86_64-linux = packages // {
      all = pkgs.buildEnv {
        name = "toolbox-all";
        paths = lib.attrValues packages;
      };
      default = pkgs.buildEnv {
        name = "toolbox-all";
        paths = lib.attrValues packages;
      };
    };
  };
}