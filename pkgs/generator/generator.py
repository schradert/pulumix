#!/usr/bin/env python3
"""
Pulumi Schema to Nix Module Generator

This script converts Pulumi package schemas into Nix module definitions,
similar to how terranix works for Terraform.
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Dict, Any, List, Optional, Set
from urllib.parse import urlparse
import re


class PulumiToNixGenerator:
    def __init__(self):
        self.seen_types: Set[str] = set()
        self.type_definitions: Dict[str, str] = {}
        
    def sanitize_nix_identifier(self, name: str) -> str:
        """Convert a name to a valid Nix identifier"""
        # Replace invalid characters with underscores
        sanitized = re.sub(r'[^a-zA-Z0-9_]', '_', name)
        # Ensure it doesn't start with a number
        if sanitized and sanitized[0].isdigit():
            sanitized = f"_{sanitized}"
        return sanitized or "unnamed"
    
    def pulumi_type_to_nix_type(self, type_info: Dict[str, Any]) -> str:
        """Convert Pulumi type information to Nix type expression"""
        if not isinstance(type_info, dict):
            return "types.unspecified"
            
        pulumi_type = type_info.get("type", "")
        
        # Handle primitive types
        if pulumi_type == "boolean":
            return "types.bool"
        elif pulumi_type == "integer":
            return "types.int"
        elif pulumi_type == "number":
            return "types.number"
        elif pulumi_type == "string":
            return "types.str"
        elif pulumi_type == "array":
            items_type = self.pulumi_type_to_nix_type(type_info.get("items", {}))
            return f"types.listOf ({items_type})"
        elif pulumi_type == "object":
            # For generic objects, use attrs
            if "additionalProperties" in type_info:
                value_type = self.pulumi_type_to_nix_type(type_info["additionalProperties"])
                return f"types.attrsOf ({value_type})"
            return "types.attrs"
        
        # Handle references to other types
        if "$ref" in type_info:
            ref = type_info["$ref"]
            if ref.startswith("#/types/"):
                type_name = ref.split("/")[-1]
                return f"self.types.{self.sanitize_nix_identifier(type_name)}"
            elif ref.startswith("#/resources/"):
                resource_name = ref.split("/")[-1]
                return f"self.resources.{self.sanitize_nix_identifier(resource_name)}"
        
        # Handle oneOf (union types)
        if "oneOf" in type_info:
            # In Nix, we'll represent this as either/or types or just attrs for flexibility
            return "types.attrs"
            
        return "types.attrs"  # Default fallback
    
    def generate_property_definition(self, name: str, prop: Dict[str, Any]) -> str:
        """Generate a compact Nix property definition from a Pulumi property"""
        nix_name = self.sanitize_nix_identifier(name)
        nix_type = self.pulumi_type_to_nix_type(prop)
        
        # Build compact property definition
        parts = [f'type = {nix_type};']
        
        # Add description if available
        if "description" in prop:
            description = prop["description"].replace('"', '\\"').replace('\n', '\\n')
            parts.append(f'description = "{description}";')
        
        # Handle default values
        if "default" in prop:
            default_val = json.dumps(prop["default"])
            parts.append(f'default = {default_val};')
        elif not prop.get("required", False):
            parts.append('default = null;')
        
        return f'{nix_name} = mkOption {{ {" ".join(parts)} }};'
    
    def generate_object_type(self, name: str, obj_type: Dict[str, Any]) -> str:
        """Generate a compact Nix type definition for a complex object type"""
        nix_name = self.sanitize_nix_identifier(name)
        
        if nix_name in self.seen_types:
            return ""
        self.seen_types.add(nix_name)
        
        # Process properties into compact definitions
        properties = obj_type.get("properties", {})
        required = obj_type.get("required", [])
        
        prop_defs = []
        for prop_name, prop_def in properties.items():
            prop_with_required = dict(prop_def)
            prop_with_required["required"] = prop_name in required
            prop_defs.append(self.generate_property_definition(prop_name, prop_with_required))
        
        options_content = " ".join(prop_defs) if prop_defs else ""
        return f'{nix_name} = types.submodule {{ options = {{ {options_content} }}; }};'
    
    def generate_resource_definition(self, name: str, resource: Dict[str, Any]) -> str:
        """Generate a compact Nix resource definition from a Pulumi resource"""
        nix_name = self.sanitize_nix_identifier(name)
        
        # Common resource properties
        common_props = [
            'dependsOn = mkOption { type = types.listOf types.str; default = []; description = "List of resources this resource depends on"; };',
            'provider = mkOption { type = types.nullOr types.str; default = null; description = "Provider instance to use for this resource"; };'
        ]
        
        # Process resource-specific input properties
        input_props = resource.get("inputProperties", {})
        required_inputs = resource.get("requiredInputs", [])
        
        resource_props = []
        for prop_name, prop_def in input_props.items():
            prop_with_required = dict(prop_def)
            prop_with_required["required"] = prop_name in required_inputs
            resource_props.append(self.generate_property_definition(prop_name, prop_with_required))
        
        all_props = common_props + resource_props
        options_content = " ".join(all_props)
        
        return f'{nix_name} = types.submodule {{ options = {{ {options_content} }}; }};'
    
    def generate_nix_module(self, schema: Dict[str, Any]) -> str:
        """Generate the complete compact Nix module from a Pulumi schema"""
        package_name = schema.get("name", "unknown")
        version = schema.get("version", "0.0.0")
        description = schema.get("description", f"Pulumi {package_name} package")
        
        # Generate compact type definitions
        types = schema.get("types", {})
        type_defs = []
        for type_name, type_def in types.items():
            type_definition = self.generate_object_type(type_name, type_def)
            if type_definition:
                type_defs.append(type_definition)
        
        types_content = " ".join(type_defs) if type_defs else ""
        
        # Generate compact resource definitions
        resources = schema.get("resources", {})
        resource_defs = []
        for resource_name, resource_def in resources.items():
            resource_definition = self.generate_resource_definition(resource_name, resource_def)
            resource_defs.append(resource_definition)
        
        resources_content = " ".join(resource_defs) if resource_defs else ""
        
        # Generate compact function definitions
        functions = schema.get("functions", {})
        func_defs = []
        if functions:
            for func_name, func_def in functions.items():
                nix_name = self.sanitize_nix_identifier(func_name)
                
                # Function inputs
                inputs_content = ""
                inputs = func_def.get("inputs", {})
                if inputs and "properties" in inputs:
                    input_props = []
                    for input_name, input_def in inputs["properties"].items():
                        input_props.append(self.generate_property_definition(input_name, input_def))
                    inputs_content = f'inputs = {{ {" ".join(input_props)} }};' if input_props else ""
                
                # Function outputs  
                outputs_content = ""
                outputs = func_def.get("outputs", {})
                if outputs and "properties" in outputs:
                    output_props = []
                    for output_name, output_def in outputs["properties"].items():
                        output_props.append(self.generate_property_definition(output_name, output_def))
                    outputs_content = f'outputs = {{ {" ".join(output_props)} }};' if output_props else ""
                
                func_content = " ".join(filter(None, [inputs_content, outputs_content]))
                func_defs.append(f'{nix_name} = {{ {func_content} }};')
        
        functions_content = " ".join(func_defs) if func_defs else ""
        
        # Build the complete module as a single expression
        module_parts = [
            f'packageName = "{package_name}";',
            f'version = "{version}";',
            f'types = {{ {types_content} }};',
            f'resources = {{ {resources_content} }};'
        ]
        
        if functions_content:
            module_parts.append(f'functions = {{ {functions_content} }};')
        
        return f'{{ lib, ... }}: with lib; rec {{ {" ".join(module_parts)} }}'


def main():
    parser = argparse.ArgumentParser(
        description="Generate Nix modules from Pulumi package schemas"
    )
    parser.add_argument(
        "schema_file",
        help="Path to the Pulumi package schema JSON file"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file path (default: stdout)"
    )
    parser.add_argument(
        "--package-name",
        help="Override the package name from schema"
    )
    
    args = parser.parse_args()
    
    # Load the schema
    try:
        with open(args.schema_file, 'r') as f:
            schema = json.load(f)
    except FileNotFoundError:
        print(f"Error: Schema file '{args.schema_file}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in schema file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Override package name if provided
    if args.package_name:
        schema["name"] = args.package_name
    
    # Generate the Nix module
    generator = PulumiToNixGenerator()
    nix_module = generator.generate_nix_module(schema)
    
    # Output the result
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            f.write(nix_module)
        print(f"Generated Nix module: {output_path}")
    else:
        print(nix_module)


if __name__ == "__main__":
    main()
