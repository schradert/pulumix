# Pulumix

Generate Nix module definitions from Pulumi package schemas - the terranix equivalent for Pulumi.

## Overview

Pulumix automatically converts Pulumi package schemas into Nix module definitions, allowing you to:

- Define Pulumi infrastructure using Nix's powerful module system
- Get type checking and validation for your Pulumi configurations
- Leverage Nix's lazy evaluation and composability for infrastructure code
- Generate reusable, parameterized infrastructure components

## Quick Start

### Prerequisites

- Python 3.6+
- Bash
- curl
- Nix (optional, for validation)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/schradert/pulumix.git
cd pulumix
```

2. Make scripts executable:
```bash
make install
```

### Basic Usage

Generate a Nix module for the AWS provider:
```bash
make aws
```

Generate modules for all major cloud providers:
```bash
make all
```

Use the shell script directly:
```bash
./generate.sh aws
./generate.sh azure -v 5.0.0
./generate.sh -s custom-schema.json
```

## Generated Module Structure

Each generated Nix module contains:

- **Package metadata**: Name, version, description
- **Type definitions**: Complex types used by resources and functions
- **Resource definitions**: All resources with their input/output properties
- **Function definitions**: Provider functions with inputs/outputs

Example generated structure:
```nix
{
  packageName = "aws";
  version = "6.0.0";
  
  types = {
    # Complex type definitions
    s3_bucket_config = types.submodule { ... };
  };
  
  resources = {
    # Resource definitions  
    s3_bucket = types.submodule {
      options = {
        bucket = mkOption { type = types.str; ... };
        # ... other properties
      };
    };
  };
  
  functions = {
    # Function definitions
    get_caller_identity = { ... };
  };
}
```

## Available Commands

### Make Targets

```bash
make help           # Show all available commands
make all            # Generate all major cloud providers
make clean          # Clean generated files and schemas
make aws            # Generate AWS provider module
make azure          # Generate Azure provider module  
make gcp            # Generate Google Cloud provider module
make kubernetes     # Generate Kubernetes provider module
make test           # Validate generated modules
make package        # Create distributable package
```

### Shell Script Options

```bash
./generate.sh [PROVIDER] [OPTIONS]

Options:
  -h, --help         Show help message
  -o, --output DIR   Output directory (default
