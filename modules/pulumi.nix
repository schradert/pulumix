{lib, ...}: let
  inherit (lib) mkOption types;
  inherit (types) anything attrsOf bool either int nullOr str submodule;
in {
  options.pulumi = {
    name = mkOption {
      default = "main";
      type = str;
      description = "Name of the project containing alphanumeric characters, hyphens, underscores, and periods.";
    };
    description = mkOption {
      default = null;
      type = nullOr str;
      description = "Description of the project.";
    };
    author = mkOption {
      default = null;
      type = nullOr str;
      description = "Author is an optional author that created this project.";
    };
    website = mkOption {
      default = null;
      type = nullOr str;
      description = "Website is an optional website for additional info about this project.";
    };
    license = mkOption {
      default = null;
      type = nullOr str;
      description = "License is the optional license governing this project's usage.";
    };
    runtime = mkOption {
      default = "yaml";
      type = either str (submodule {
        options = {
          name = mkOption {
            type = str;
          };
          options = mkOption {
            type = attrsOf anything;
          };
        };
      });
    };
    main = mkOption {
      default = null;
      type = nullOr str;
      description = "Path to the Pulumi program. The default is the working directory.";
    };
    config = mkOption {
      default = null;
      type = nullOr (submodule {
        freeformType = let
          simpleConfigType = enum ["string" "integer" "boolean" "array"];
          configItemsType = submodule {
            options = {
              type = mkOption {
                type = either simpleConfigType configItemsType;
              };
              items = mkOption {
                type = configItemsType;
              };
              # FIXME what to do about if-then?
            };
          };
          configTypeDeclaration = submodule {
            options = {
              type = mkOption {
                type = simpleConfigType;
              };
              items = mkOption {
                type = configItemsType;
              };
              description = mkOption {
                type = str;
              };
              secret = mkOption {
                type = bool;
              };
              default = mkOption {
                type = anything;
              };
              value = mkOption {
                type = anything;
              };
            };
          };
        in oneOf [str int bool (listOf anything) configTypeDeclaration];
        options.secret = mkOption {
          default = false;
          type = bool;
          description = "If true this configuration value should be encrypted.";
        };
      });
    };
    stackConfigDir = mkOption {
      default = null;
      type = nullOr str;
      description = "Config directory location relative to the location of Pulumi.yaml.";
    };
    backend = mkOption {
      default = null;
      type = submodule {
        options.url = mkOption {
          default = null;
          type = nullOr str;
          description = "URL is optional field to explicitly set backend url";
        };
      };
      description = "Backend of the project.";
    };
    options = mkOption {
      default = null;
      type = nullOr (submodule {
        options.refresh = mkOption {
          default = "always";
          type = enum ["always"];
          description = "Set to \"always\" to refresh state before performing a Pulumi operation.";
        };
      });
      description = "Additional project options";
    };
    template = mkOption {
      default = null;
      type = nullOr (submodule {
        options = {
          description = mkOption {
            default = null;
            type = nullOr str;
            description = "Description of the template.";
          };
          quickstart = mkOption {
            default = null;
            type = nullOr str;
            description = "Quickstart contains optional text to be displayed after template creation.";
          };
          important = mkOption {
            default = null;
            type = nullOr bool;
            description = "Important indicates the tempalte is important and should be listed by default.";
          };
          config = mkOption {
            default = null;
            type = nullOr (submodule {
              options = {
                description = mkOption {
                  default = null;
                  type = nullOr str;
                  description = "Description of the config.";
                };
                default = mkOption {
                  type = anything;
                  description = "Default value of the config.";
                };
                secret = mkOption {
                  default = null;
                  type = nullOr bool;
                  description = "Boolean indicating if the configuration is labeled as a secret.";
                };
              };
            });
            description = "Config to apply to each stack in the project.";
          };
        };
      });
      description = "ProjectTemplate is a Pulumi project template manifest.";
    };
    plugins = mkOption {
      default = {};
      type = submodule {
        options = let
          pluginOptions = submodule {
            options = {
              name = mkOption {
                type = str;
                description = "Name of the plugin";
              };
              path = mkOption {
                type = str;
                description = "Path to the plugin folder.";
              };
              version = mkOption {
                type = str;
                description = "Version of the plugin, if not set, will match any version the engine requests.";
              };
            };
          };
        in {
          providers = mkOption {
            default = [];
            type = listOf pluginOptions;
            description = "Plugins for resource providers.";
          };
          analyzers = mkOption {
            default = [];
            type = listOf pluginOptions;
            description = "Plugins for policy analyzers.";
          };
          languages = mkOption {
            default = [];
            type = listOf pluginOptions;
            description = "Plugins for languages."; 
          };
        };
      };
      description = "Override for the plugin selection. Intended for use in developing pulumi plugins.";
    };
  };
}
