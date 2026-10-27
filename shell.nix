# Host tools to drive the build on NixOS: `nix-shell --run make`. Everything else runs in the podman container.
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [ gnumake curl gnutar xz coreutils ];
}
