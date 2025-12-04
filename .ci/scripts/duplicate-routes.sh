#!/bin/bash

# Setup logger
log() {
  local level="$1"
  local message="$2"
  echo "[$level] $message"
}

# Read the kong.yaml file
config=$(yq eval '.' "$1/kong.yaml")

# Initialize variables
declare -A route_map
error_messages=()

# Iterate over services
services=$(echo "$config" | yq eval '.services' -)
for service in $(echo "$services" | yq eval 'keys' -); do
  service_name=$(echo "$services" | yq eval ".[$service].name" -)
  routes=$(echo "$services" | yq eval ".[$service].routes" -)

  if [ "$routes" == "null" ]; then
    error_messages+=("No routes found in service $service_name")
    continue
  fi

  # Iterate over routes
  for route in $(echo "$routes" | yq eval 'keys' -); do
    route_name=$(echo "$routes" | yq eval ".[$route].name" -)

    # Ignore fallback-route
    if [ "$route_name" == "fallback-route" ]; then
      continue
    fi

    methods=$(echo "$routes" | yq eval ".[$route].methods" -)
    paths=$(echo "$routes" | yq eval ".[$route].paths" -)

    if [ "$methods" == "null" ]; then
      error_messages+=("No methods found for route: $route_name")
      continue
    fi

    if [ "$paths" == "null" ]; then
      error_messages+=("No paths found for $route_name")
      continue
    fi

    # Check for duplicate paths with methods
    for method in $(echo "$methods" | yq eval '.[]' -); do
      for path in $(echo "$paths" | yq eval '.[]' -); do
        path_with_method="$method $path"
        if [ "${route_map[$path_with_method]}" ]; then
          error_messages+=("Duplicate path found.\nPath: $path_with_method\nRoute: $route_name")
          continue
        fi
        route_map["$path_with_method"]=true
      done
    done
  done
done

# Log errors
for error_message in "${error_messages[@]}"; do
  log "ERROR" "$error_message"
done

# Exit with error if there are any error messages
if [ ${#error_messages[@]} -gt 0 ]; then
  exit 1
fi
