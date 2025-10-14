#!/usr/bin/env bash
set -euo pipefail

# Pulumix - Generate Nix modules from Pulumi schemas
# Usage: ./generate-pulumi-nix.sh [provider-name] [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR_SCRIPT="$SCRIPT_DIR/generator.py"
SCHEMAS_DIR="$SCRIPT_DIR/schemas"
OUTPUT_DIR="$SCRIPT_DIR/generated"

show_help() {
    cat << EOF
Pulumix - Generate Nix modules from Pulumi schemas

Usage: $0 [PROVIDER] [OPTIONS]

Arguments:
  PROVIDER            Pulumi provider name (e.g., aws, azure, gcp)
                     If not provided, processes all schemas in schemas/

Options:
  -h, --help         Show this help message
  -o, --output DIR   Output directory (default: ./generated)
  -s, --schema FILE  Use specific schema file instead of downloading
  -v, --version VER  Specific provider version to fetch
  --clean            Clean output directory before generating
  --download-only    Only download schemas, don't generate

Examples:
  $0 aws                    # Generate Nix module for AWS provider
  $0 aws -v 6.0.0          # Generate for specific AWS version
  $0 --clean               # Clean and regenerate all providers
  $0 -s my-schema.json     # Use custom schema file

Environment Variables:
  PULUMI_REGISTRY_URL      Base URL for Pulumi registry (default: registry-1.pulumi.io)
  NO_FORMAT               Skip alejandra formatting (set to 1 to disable)

Dependencies:
  - python3               Required for schema processing
  - curl                  Required for downloading schemas  
  - alejandra             Optional, for formatting generated Nix files
                         Install with: nix profile install nixpkgs#alejandra
EOF
}

download_schema() {
    local provider="$1"
    local version="${2:-latest}"
    local output_file="$3"
    
    local registry_url="${PULUMI_REGISTRY_URL:-https://api.pulumi.com/api}"
    
    echo "Downloading schema for $provider@$version..."
    
    # Create schemas directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    if [[ "$version" == "latest" ]]; then
        # Get latest version first
        version=$(curl -s "$registry_url/packages/$provider" | \
                 python3 -c "import json, sys; print(json.load(sys.stdin)['versions'][0]['version'])" 2>/dev/null || echo "")
        
        if [[ -z "$version" ]]; then
            echo "Warning: Could not determine latest version for $provider, trying direct schema fetch..."
            version="latest"
        fi
    fi
    
    # Try to download the schema
    local schema_url="https://github.com/pulumi/pulumi-$provider/raw/master/provider/cmd/pulumi-resource-$provider/schema.json"
    
    if curl -sSL "$schema_url" -o "$output_file"; then
        echo "✓ Downloaded schema for $provider"
        return 0
    else
        echo "✗ Failed to download schema for $provider from $schema_url"
        # Try alternative location
        schema_url="https://github.com/pulumi/pulumi-$provider/raw/main/provider/cmd/pulumi-resource-$provider/schema.json"
        if curl -sSL "$schema_url" -o "$output_file"; then
            echo "✓ Downloaded schema for $provider (from main branch)"
            return 0
        else
            echo "✗ Failed to download schema for $provider"
            return 1
        fi
    fi
}

generate_nix_module() {
    local schema_file="$1"
    local output_file="$2"
    local provider_name="$3"
    
    echo "Generating Nix module for $provider_name..."
    
    if [[ ! -f "$GENERATOR_SCRIPT" ]]; then
        echo "Error: Generator script not found at $GENERATOR_SCRIPT"
        exit 1
    fi
    
    # Generate the compact Nix module
    if ! python3 "$GENERATOR_SCRIPT" "$schema_file" --output "$output_file" --package-name "$provider_name"; then
        echo "✗ Failed to generate Nix module for $provider_name"
        return 1
    fi
    
    # Format with alejandra if available and not disabled
    if [[ "${NO_FORMAT:-0}" != "1" ]] && command -v alejandra >/dev/null 2>&1; then
        echo "Formatting with alejandra..."
        if alejandra "$output_file" 2>/dev/null; then
            echo "✓ Formatted with alejandra"
        else
            echo "⚠ alejandra formatting failed, but module was generated"
        fi
    elif [[ "${NO_FORMAT:-0}" == "1" ]]; then
        echo "Skipping formatting (NO_FORMAT=1)"
    else
        echo "⚠ alejandra not found - install with 'nix profile install nixpkgs#alejandra' for formatting"
    fi
    
    echo "✓ Generated Nix module: $output_file"
    return 0
}

process_provider() {
    local provider="$1"
    local version="${2:-latest}"
    local custom_schema="${3:-}"
    
    local schema_file
    local output_file="$OUTPUT_DIR/$provider.nix"
    
    if [[ -n "$custom_schema" ]]; then
        schema_file="$custom_schema"
    else
        schema_file="$SCHEMAS_DIR/$provider.json"
        if [[ ! -f "$schema_file" ]] || [[ "${DOWNLOAD_SCHEMAS:-1}" == "1" ]]; then
            download_schema "$provider" "$version" "$schema_file" || return 1
        fi
    fi
    
    if [[ "${DOWNLOAD_ONLY:-0}" == "1" ]]; then
        echo "Download-only mode: skipping generation for $provider"
        return 0
    fi
    
    generate_nix_module "$schema_file" "$output_file" "$provider"
}

main() {
    local provider=""
    local version="latest"
    local custom_schema=""
    local clean=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -s|--schema)
                custom_schema="$2"
                shift 2
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            --clean)
                clean=1
                shift
                ;;
            --download-only)
                export DOWNLOAD_ONLY=1
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                show_help >&2
                exit 1
                ;;
            *)
                if [[ -z "$provider" ]]; then
                    provider="$1"
                else
                    echo "Too many arguments" >&2
                    show_help >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Clean output directory if requested
    if [[ "$clean" == "1" ]]; then
        echo "Cleaning output directory: $OUTPUT_DIR"
        rm -rf "$OUTPUT_DIR"
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    if [[ -n "$provider" ]]; then
        # Process single provider
        process_provider "$provider" "$version" "$custom_schema"
    elif [[ -n "$custom_schema" ]]; then
        # Process custom schema
        local basename=$(basename "$custom_schema" .json)
        process_provider "$basename" "$version" "$custom_schema"
    else
        # Process all schemas in schemas directory
        if [[ ! -d "$SCHEMAS_DIR" ]] || [[ -z "$(ls -A "$SCHEMAS_DIR" 2>/dev/null)" ]]; then
            echo "No schemas found in $SCHEMAS_DIR"
            echo "Try downloading some schemas first:"
            echo "  $0 aws"
            echo "  $0 azure"
            echo "  $0 gcp"
            exit 1
        fi
        
        echo "Processing all schemas in $SCHEMAS_DIR..."
        for schema_file in "$SCHEMAS_DIR"/*.json; do
            if [[ -f "$schema_file" ]]; then
                local basename=$(basename "$schema_file" .json)
                process_provider "$basename" "$version" "$schema_file"
            fi
        done
    fi
    
    echo "✓ Done! Generated modules are in: $OUTPUT_DIR"
}

main "$@"
