{config, lib, ...}: let
  inherit (builtins) attrValues listToAttrs mapAttrs;
  inherit (lib) concatMapAttrs mapAttrs' mapAttrsToList mkAliasOptionModule mkDefault mkMerge mkOption nameValuePair pipe types;
in {
  imports = [
    (mkAliasOptionModule ["outputs"] ["pulumi" "outputs"])
    (mkAliasOptionModule ["variables"] ["pulumi" "variables"])
  ];
  options = {
    configs = mkOption {
      type = with types; attrsOf (attrsOf str);
      default = {};
    };
    resources = mkOption {
      type = with types; attrsOf (attrsOf (attrsOf (attrsOf anything)));
      default = {};
    };
  };
  config._module.args.pulumix.hcloud.getPrimaryIp = arguments: {
    "fn::invoke" = {
      function = "hcloud:getPrimaryIp";
      inherit arguments;
    };
  };
  config.pulumi = {
    config = let
      mapValues = prefix: mapAttrs' (name: value: nameValuePair "${prefix}:${name}" {inherit value;});
    in pipe config.configs [(mapAttrs mapValues) attrValues mkMerge];
    resources = pipe config.resources [
      # resources.<provider>.<type>.<name>.<props> -> [{name, provider, type, props}]
      (concatMapAttrs (provider: types:
        concatMapAttrs (type: instances:
          mapAttrsToList (name: props: {
            inherit provider type name props;
          }) instances
        ) types
      ))
      (map (resource: nameValuePair resource.name {
        type = "${resource.provider}:${resource.type}";
        properties = mkMerge [resource.properties {name = mkDefault resource.name;}];
      }))
      listToAttrs
    ];
  };
}
