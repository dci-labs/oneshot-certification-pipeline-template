#!/bin/bash
#
# Purpose: To setup a DCI PIPELNE for oneshot certification automatically.
# Althought it aims for oneshot certification setup but also it can use for other use-cases
# like preliminary checking for container/operator, helmchart and KPBC testing.
#
# Exit on error except for the SSH check
# set -e

# Validate input parameter
if [ -z "$1" ]; then
    echo "Usage: $0 <custom_pipeline_name>"
    exit 1
fi

custom_pipeline_name="$1"
echo "custom_pipeline_name: $custom_pipeline_name"

# Function to display error messages and exit
function error_exit {
    echo "Error: $1"
    exit 1
}

# Check if git SSH is configured and working
ssh_output=$(ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1)
if [[ "$ssh_output" != *"Hi "* || "$ssh_output" != *"successfully authenticated"* ]]; then
    error_exit "Git SSH authentication to github.com failed. Output: $ssh_output"
else
    echo "SSH authentication to GitHub succeeded."
fi

# Clone the template repository
repo_url="git@github.com:dci-labs/oneshot-certification-pipeline-template.git"
if ! git clone "$repo_url" &> /dev/null; then
    error_exit "Failed to clone repository from $repo_url"
else
    echo "Cloned this $repo_url Successfully!"
fi

# Rename the cloned directory
if ! mv oneshot-certification-pipeline-template "$custom_pipeline_name"; then
    error_exit "Failed to rename the cloned repository directory."
fi

# Create required directories
mkdir -p dci-cache-dir upload-errors .config/dci-pipeline

# Create configuration file
config_path=".config/dci-pipeline/config"
cat > "$config_path" <<EOF
PIPELINES_DIR="$HOME/${custom_pipeline_name}/pipelines"
DEFAULT_QUEUE=pool
EOF
echo "Configuration file created at $config_path."

# Replace placeholders in pipeline files
pipeline_dir="${custom_pipeline_name}/pipelines"
if [ -d "$pipeline_dir" ]; then
    grep -rl 'oneshot-certification-pipeline-template' "$pipeline_dir" | xargs sed -i "s/oneshot-certification-pipeline-template/${custom_pipeline_name}/g"
    echo "Replaced placeholders in pipeline files."
else
    error_exit "Pipeline directory not found: $pipeline_dir"
fi

# Add a pool to the DCI queue
echo "Adding pool 'pool' to the DCI queue..."
if ! dci-queue add-pool pool; then
    error_exit "Failed to add pool 'pool' to the DCI queue."
    
fi

# Add a resource to the pool
echo "Adding resource 'cluster1' to pool 'pool'..."
if ! dci-queue add-resource pool cluster1; then
    error_exit "Failed to add resource 'cluster1' to pool 'pool'."
fi

echo "Setup completed successfully for pipeline: $custom_pipeline_name"
