#!/bin/bash

# Script to generate GitHub Actions workflow test steps from Dart test files
# Usage: cd to project root and run: ./scripts/generate_gh_workflow_tests.sh
# Or from scripts dir: cd scripts && ./generate_gh_workflow_tests.sh

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root to ensure relative paths work
cd "$PROJECT_ROOT"

# Function to process a test file and update its corresponding workflow
process_test_file() {
    local dart_test_file=$1
    local workflow_file=$2
    local test_prefix=$3
    local test_type=$4

    echo ""
    echo "========================================="
    echo "Processing $test_type tests..."
    echo "========================================="

    if [ ! -f "$dart_test_file" ]; then
        echo "⚠ Warning: Test file not found at $dart_test_file"

        # If the test file doesn't exist and it's optional, clean up the workflow
        if [ "$test_type" == "optional" ] && [ -f "$workflow_file" ]; then
            echo "Cleaning up $workflow_file (removing all test steps)..."

            temp_file=$(mktemp)
            in_tests_section=false
            skip_until_reporter=false
            in_env_section=false

            while IFS= read -r line; do
                # Mark section after Setup Flutter or Dart Analyze
                if [[ $line =~ "- name: Setup Flutter" ]] || [[ $line =~ "- name: Dart Analyze check" ]]; then
                    in_tests_section=true
                    echo "$line" >> "$temp_file"
                    continue
                fi

                if [[ $line =~ "- name: Autograding Reporter" ]]; then
                    if $in_tests_section; then
                        skip_until_reporter=false
                        in_tests_section=false
                    fi
                    echo "$line" >> "$temp_file"
                    continue
                fi

                # Skip any test steps between Setup/Analyze and Reporter
                if $in_tests_section && [[ $line =~ "- name: Test" ]]; then
                    skip_until_reporter=true
                fi

                if ! $skip_until_reporter; then
                    if [[ $line =~ "runners:" ]]; then
                        # Extract existing dart_analyze from runners if present
                        if [[ $line =~ "dart_analyze" ]]; then
                            echo "          runners: dart_analyze" >> "$temp_file"
                        else
                            echo "          runners:" >> "$temp_file"
                        fi
                    elif $in_env_section && [[ $line =~ ^[[:space:]]+[MO]_TEST[0-9]+_RESULTS: ]]; then
                        # Skip all test result env vars
                        continue
                    elif $in_env_section && [[ $line =~ ^[[:space:]]+DART_ANALYZE_RESULTS: ]]; then
                        # Keep DART_ANALYZE_RESULTS if it exists
                        echo "$line" >> "$temp_file"
                    elif [[ $line =~ "env:" ]]; then
                        in_env_section=true
                        echo "$line" >> "$temp_file"
                    elif $in_env_section && [[ ! $line =~ ^[[:space:]]+ ]] && [[ ! $line =~ ^[[:space:]]*$ ]]; then
                        in_env_section=false
                        echo "$line" >> "$temp_file"
                    else
                        echo "$line" >> "$temp_file"
                    fi
                fi
            done < "$workflow_file"

            mv "$temp_file" "$workflow_file"
            echo "✓ Workflow cleaned (all test steps removed)"
        fi
        return 1
    fi

    if [ ! -f "$workflow_file" ]; then
        echo "Error: Workflow file not found at $workflow_file"
        return 1
    fi

    # Check if workflow has required structure (Autograding Reporter)
    if ! grep -q "Autograding Reporter" "$workflow_file"; then
        echo "⚠ Warning: Workflow file is missing Autograding Reporter section"
        echo "Please ensure the workflow has the complete structure before running this script."
        return 1
    fi

    echo "Extracting test names from $dart_test_file..."

    # Extract test names from the Dart file
    test_names=()
    while IFS= read -r line; do
        if [[ $line =~ testWidgets\([[:space:]]*[\'\"](.*)[\'\"],[[:space:]]*\(WidgetTester ]]; then
            test_name="${BASH_REMATCH[1]}"
            test_names+=("$test_name")
        fi
    done < "$dart_test_file"

    echo "Found ${#test_names[@]} tests"

    # Generate the test steps YAML content
    test_steps=""
    test_ids=()
    counter=1

    for test_name in "${test_names[@]}"; do
        test_id="${test_prefix}_test${counter}"
        test_ids+=("$test_id")

        test_steps+="
      - name: Test $counter
        id: $test_id
        uses: education/autograding-command-grader@v1
        with:
          test-name: \"$test_name\"
          command: flutter test --name \"$test_name\"
          timeout: 10
          max-score: 1
"
        ((counter++))
    done

    # Generate the runners list for the Autograding Reporter
    # Check if Dart Analyze exists in the workflow by looking at the runners line
    existing_runners=$(grep "runners:" "$workflow_file" | head -1)

    if [[ $existing_runners =~ dart_analyze ]]; then
        # Dart Analyze exists, keep it at the beginning
        runners_list="dart_analyze"
        for test_id in "${test_ids[@]}"; do
            runners_list+=",${test_id}"
        done
    else
        # No Dart Analyze, start with first test
        runners_list=""
        first=true
        for test_id in "${test_ids[@]}"; do
            if $first; then
                runners_list="$test_id"
                first=false
            else
                runners_list+=",${test_id}"
            fi
        done
    fi

    echo "Generating new workflow content..."

    # Create temporary file with new content
    temp_file=$(mktemp)

    # Read the original file line by line and build the new content
    in_tests_section=false
    skip_until_reporter=false
    in_env_section=false
    wrote_test_vars=false

    # Check if this workflow has Dart Analyze
    has_dart_analyze=$(grep -q "Dart Analyze check" "$workflow_file" && echo "true" || echo "false")

    while IFS= read -r line; do
        # Determine insertion point based on whether Dart Analyze exists
        if $has_dart_analyze && [[ $line =~ "- name: Dart Analyze check" ]]; then
            in_tests_section=true
            echo "$line" >> "$temp_file"
            continue
        elif ! $has_dart_analyze && [[ $line =~ "- name: Setup Flutter" ]]; then
            in_tests_section=true
            echo "$line" >> "$temp_file"
            continue
        fi

        # If we're in the tests section and hit the Autograding Reporter, stop skipping
        if [[ $line =~ "- name: Autograding Reporter" ]]; then
            if $in_tests_section; then
                # Insert our generated test steps before the reporter
                echo "$test_steps" >> "$temp_file"
                skip_until_reporter=false
                in_tests_section=false
            fi
            echo "$line" >> "$temp_file"
            continue
        fi

        # If we're past insertion point and before Reporter, skip original test steps
        if $in_tests_section && [[ $line =~ "- name: Test" ]]; then
            skip_until_reporter=true
        fi

        if ! $skip_until_reporter; then
            # Update the runners line if we find it
            if [[ $line =~ "runners:" ]]; then
                echo "          runners: $runners_list" >> "$temp_file"
            # Detect env section start
            elif [[ $line =~ "env:" ]]; then
                in_env_section=true
                echo "$line" >> "$temp_file"
            # Keep DART_ANALYZE_RESULTS if it exists
            elif $in_env_section && [[ $line =~ ^[[:space:]]+DART_ANALYZE_RESULTS: ]]; then
                echo "$line" >> "$temp_file"
            # Handle test RESULTS lines in env section - skip old ones
            elif $in_env_section && [[ $line =~ ^[[:space:]]+TEST[0-9]+_RESULTS: ]]; then
                # Skip old TEST vars without prefix
                if ! $wrote_test_vars; then
                    # Write all TEST vars in numerical order
                    for test_id in "${test_ids[@]}"; do
                        test_id_upper=$(echo "$test_id" | tr '[:lower:]' '[:upper:]')
                        echo "          ${test_id_upper}_RESULTS: \${{ steps.${test_id}.outputs.result }}" >> "$temp_file"
                    done
                    wrote_test_vars=true
                fi
            # Handle test RESULTS lines with M_ or O_ prefix - skip and replace
            elif $in_env_section && [[ $line =~ ^[[:space:]]+[MO]_TEST[0-9]+_RESULTS: ]]; then
                # Skip - we'll write all TEST vars in sorted order later
                if ! $wrote_test_vars; then
                    # Write all TEST vars in numerical order
                    for test_id in "${test_ids[@]}"; do
                        test_id_upper=$(echo "$test_id" | tr '[:lower:]' '[:upper:]')
                        echo "          ${test_id_upper}_RESULTS: \${{ steps.${test_id}.outputs.result }}" >> "$temp_file"
                    done
                    wrote_test_vars=true
                fi
            # Handle SHEETS_CREDENTIALS (insert TEST vars before it if not done yet)
            elif $in_env_section && [[ $line =~ "SHEETS_CREDENTIALS:" ]]; then
                if ! $wrote_test_vars; then
                    # Write all TEST vars in numerical order before SHEETS_CREDENTIALS
                    for test_id in "${test_ids[@]}"; do
                        test_id_upper=$(echo "$test_id" | tr '[:lower:]' '[:upper:]')
                        echo "          ${test_id_upper}_RESULTS: \${{ steps.${test_id}.outputs.result }}" >> "$temp_file"
                    done
                    wrote_test_vars=true
                fi
                echo "$line" >> "$temp_file"
            # Detect when we exit the env section
            elif $in_env_section && [[ $line =~ ^[[:space:]]*$ ]]; then
                # Empty line, still in env
                echo "$line" >> "$temp_file"
            elif $in_env_section && [[ ! $line =~ ^[[:space:]]+ ]] && [[ ! $line =~ ^[[:space:]]*$ ]]; then
                # Exited env section
                in_env_section=false
                wrote_test_vars=false
                echo "$line" >> "$temp_file"
            else
                echo "$line" >> "$temp_file"
            fi
        fi
    done < "$workflow_file"

    # Replace the original file with the new content
    mv "$temp_file" "$workflow_file"

    echo "✓ Workflow file updated successfully!"
    echo "✓ Added ${#test_names[@]} test steps"
    echo "✓ Updated runners list and environment variables"
}

# Process mandatory tests
process_test_file \
    "test/teacher/tests/widget_teacher_mandatory_test.dart" \
    ".github/workflows/mandatory_tests.yml" \
    "m" \
    "mandatory"

# Process optional tests
process_test_file \
    "test/teacher/tests/widget_teacher_optional_test.dart" \
    ".github/workflows/optional_tests.yml" \
    "o" \
    "optional"

echo ""
echo "========================================="
echo "✓ All workflows processed!"
echo "========================================="
