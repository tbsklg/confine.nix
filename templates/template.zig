//! The default env template, embedded so `confine init` writes the env this binary was built with.
pub const flake = @embedFile("default/flake.nix");
pub const config = @embedFile("default/confine.toml");
