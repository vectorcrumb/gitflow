#!/bin/bash
#
# Integration and Regression Tests for Optional Release Argument Feature
# Ensures new functionality doesn't break existing git-flow workflows
#

# Test framework setup
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
INTEGRATION_TEST_REPO_DIR="/tmp/gitflow-integration-$$"

start_test() {
    TEST_COUNT=$((TEST_COUNT + 1))
    echo -e "\n${BLUE}=== Integration Test $TEST_COUNT: $1 ===${NC}"
}

pass_test() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log_success "$1"
}

fail_test() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log_error "$1"
}

# Setup test repository with realistic git-flow history
setup_integration_repo() {
    log_info "Setting up integration test repository at $INTEGRATION_TEST_REPO_DIR"
    
    rm -rf "$INTEGRATION_TEST_REPO_DIR"
    mkdir -p "$INTEGRATION_TEST_REPO_DIR"
    cd "$INTEGRATION_TEST_REPO_DIR"
    
    # Initialize repository
    git init
    git config user.name "Integration Test User"
    git config user.email "integration@example.com"
    
    # Create initial commit
    echo "# Project" > README.md
    echo "Initial version" > version.txt
    git add .
    git commit -m "Initial commit"
    
    # Initialize git-flow
    git flow init -d
    
    # Create realistic git-flow history
    create_realistic_history
}

create_realistic_history() {
    log_info "Creating realistic git-flow history"
    
    # Create first release
    git flow release start 1.0.0
    echo "v1.0.0" > version.txt
    git add version.txt
    git commit -m "Bump version to 1.0.0"
    git flow release finish -m "Release 1.0.0" 1.0.0
    
    # Add some features
    git flow feature start authentication
    echo "Added authentication" >> features.txt
    git add features.txt
    git commit -m "Add authentication feature"
    git flow feature finish authentication
    
    git flow feature start user-profiles
    echo "Added user profiles" >> features.txt
    git add features.txt
    git commit -m "Add user profiles feature"
    git flow feature finish user-profiles
    
    # Create another release
    git flow release start 1.1.0
    echo "v1.1.0" > version.txt
    git add version.txt
    git commit -m "Bump version to 1.1.0"
    git flow release finish -m "Release 1.1.0" 1.1.0
    
    # Create a hotfix
    git flow hotfix start 1.1.1
    echo "Fixed critical bug" >> bugfixes.txt
    git add bugfixes.txt
    git commit -m "Fix critical security issue"
    git flow hotfix finish -m "Hotfix 1.1.1" 1.1.1
    
    # Create major release
    git flow release start 2.0.0
    echo "v2.0.0" > version.txt
    git add version.txt
    git commit -m "Bump version to 2.0.0"
    git flow release finish -m "Release 2.0.0" 2.0.0
    
    log_info "Created history with tags: $(git tag | tr '\n' ' ')"
}

cleanup_integration_repo() {
    cd /
    rm -rf "$INTEGRATION_TEST_REPO_DIR"
}

# Helper functions
branch_exists() {
    git branch --list | grep -q " $1$"
}

tag_exists() {
    git tag --list | grep -q "^$1$"
}

get_current_branch() {
    git branch --show-current
}

cleanup_release_branches() {
    for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
        git branch -D "$branch" 2>/dev/null || true
    done
}

#
# Regression Tests - Existing Functionality
#

test_traditional_release_workflow() {
    start_test "Traditional release workflow still works"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Traditional workflow: explicit version
    start_output=$(git flow release start 2.1.0 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start traditional release: $start_output"
        return
    fi
    
    # Make release changes
    echo "v2.1.0" > version.txt
    git add version.txt
    git commit -m "Bump version to 2.1.0"
    
    # Finish release
    finish_output=$(git flow release finish -m "Release 2.1.0" 2.1.0 2>&1)
    if [ $? -eq 0 ]; then
        if tag_exists "v2.1.0"; then
            pass_test "Traditional release workflow functions correctly"
        else
            fail_test "Release tag not created"
        fi
    else
        fail_test "Failed to finish traditional release: $finish_output"
    fi
}

test_feature_workflow_unchanged() {
    start_test "Feature workflow unaffected by release changes"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    
    # Start feature
    feature_start=$(git flow feature start test-feature 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start feature: $feature_start"
        return
    fi
    
    # Add feature changes
    echo "Test feature implementation" > feature-test.txt
    git add feature-test.txt
    git commit -m "Implement test feature"
    
    # Finish feature
    feature_finish=$(git flow feature finish test-feature 2>&1)
    if [ $? -eq 0 ]; then
        if ! branch_exists "feature/test-feature"; then
            pass_test "Feature workflow operates normally"
        else
            fail_test "Feature branch not cleaned up properly"
        fi
    else
        fail_test "Failed to finish feature: $feature_finish"
    fi
}

test_hotfix_workflow_unchanged() {
    start_test "Hotfix workflow unaffected by release changes"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    
    # Start hotfix
    hotfix_start=$(git flow hotfix start 2.0.1 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start hotfix: $hotfix_start"
        return
    fi
    
    # Add hotfix changes
    echo "Emergency hotfix" > hotfix.txt
    git add hotfix.txt
    git commit -m "Emergency security patch"
    
    # Finish hotfix
    hotfix_finish=$(git flow hotfix finish -m "Hotfix 2.0.1" 2.0.1 2>&1)
    if [ $? -eq 0 ]; then
        if tag_exists "v2.0.1"; then
            pass_test "Hotfix workflow operates normally"
        else
            fail_test "Hotfix tag not created"
        fi
    else
        fail_test "Failed to finish hotfix: $hotfix_finish"
    fi
}

#
# Integration Tests - New Feature with Existing Workflows
#

test_auto_version_after_hotfix() {
    start_test "Auto-version correctly detects version after hotfix"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Latest version should now be v2.0.1 (from hotfix)
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 2.0.2"; then
            if echo "$output" | grep -q "based on latest tag: v2.0.1"; then
                pass_test "Auto-version correctly uses hotfix as base"
            else
                fail_test "Did not identify hotfix as base: $output"
            fi
        else
            fail_test "Did not generate expected version 2.0.2: $output"
        fi
    else
        fail_test "Auto-version failed after hotfix: $output"
    fi
}

test_mixed_workflow_compatibility() {
    start_test "Mixed auto-version and explicit version workflows"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Start auto-generated release
    auto_output=$(git flow release start --major 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to start auto-generated release: $auto_output"
        return
    fi
    
    # Extract version from output
    auto_version=$(echo "$auto_output" | grep "Auto-generated version:" | sed 's/.*Auto-generated version: \([0-9.]*\).*/\1/')
    
    # Make changes and finish
    echo "v$auto_version" > version.txt
    git add version.txt
    git commit -m "Bump version to $auto_version"
    
    finish_output=$(git flow release finish -m "Release $auto_version" "$auto_version" 2>&1)
    if [ $? -ne 0 ]; then
        fail_test "Failed to finish auto-generated release: $finish_output"
        return
    fi
    
    # Now start an explicit version release
    explicit_output=$(git flow release start 4.0.0 2>&1)
    if [ $? -eq 0 ]; then
        # Should NOT show auto-generation message
        if ! echo "$explicit_output" | grep -q "Auto-generated version"; then
            pass_test "Mixed workflows work correctly"
        else
            fail_test "Explicit version showed auto-generation message"
        fi
    else
        fail_test "Failed to start explicit version release: $explicit_output"
    fi
}

test_concurrent_branch_operations() {
    start_test "Release operations don't interfere with other branches"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Start a feature branch
    git flow feature start concurrent-test
    
    # Start auto-generated release from develop (should work)
    git checkout develop
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Feature branch should still exist
        if branch_exists "feature/concurrent-test"; then
            # Should be on release branch
            current_branch=$(get_current_branch)
            if [[ "$current_branch" == release/* ]]; then
                pass_test "Release operations don't interfere with feature branches"
            else
                fail_test "Not on expected release branch: $current_branch"
            fi
        else
            fail_test "Feature branch was affected by release operation"
        fi
    else
        fail_test "Release operation failed with concurrent feature: $output"
    fi
    
    # Cleanup
    git flow feature finish concurrent-test 2>/dev/null || true
}

#
# Configuration and Environment Tests
#

test_different_branch_names() {
    start_test "Auto-version works with custom branch names"
    
    local custom_repo="/tmp/gitflow-custom-$$"
    mkdir -p "$custom_repo"
    cd "$custom_repo"
    
    git init
    git config user.name "Custom Test User"
    git config user.email "custom@example.com"
    
    echo "Initial" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    # Initialize git-flow with custom branch names
    git config gitflow.branch.master main
    git config gitflow.branch.develop devel
    git config gitflow.prefix.feature feat/
    git config gitflow.prefix.release rel/
    git config gitflow.prefix.hotfix fix/
    git config gitflow.prefix.support support/
    git config gitflow.prefix.versiontag version-
    
    git checkout -b main
    git checkout -b devel
    
    # Create version tags
    git tag version-1.0.0
    git tag version-1.1.0
    
    # Test auto-version with custom configuration
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 1.2.0"; then
            if branch_exists "rel/1.2.0"; then
                pass_test "Auto-version works with custom branch names"
            else
                fail_test "Release branch not created with custom prefix"
            fi
        else
            fail_test "Auto-version failed with custom configuration: $output"
        fi
    else
        fail_test "Command failed with custom configuration: $output"
    fi
    
    cd /
    rm -rf "$custom_repo"
}

test_remote_repository_integration() {
    start_test "Auto-version works with remote repositories"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Create a "remote" repository
    local remote_repo="/tmp/gitflow-remote-$$"
    git clone --bare . "$remote_repo"
    git remote add origin "$remote_repo"
    
    # Push branches and tags
    git push origin develop master --tags
    
    # Test auto-version with remote tracking
    output=$(git flow release start --fetch 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Should still work correctly
        if echo "$output" | grep -q "Auto-generated version:"; then
            pass_test "Auto-version works with remote repositories"
        else
            fail_test "Auto-version failed with remote: $output"
        fi
    else
        fail_test "Command failed with remote repository: $output"
    fi
    
    # Cleanup
    git remote remove origin
    rm -rf "$remote_repo"
}

#
# Backwards Compatibility Tests
#

test_script_compatibility() {
    start_test "Scripts using git-flow still work"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Create a script that uses traditional git-flow
    cat > test-script.sh << 'EOF'
#!/bin/bash
set -e

# Traditional script usage
VERSION="2.5.0"
git flow release start "$VERSION"
echo "Release $VERSION" > release-notes.txt
git add release-notes.txt
git commit -m "Add release notes for $VERSION"
git flow release finish -m "Release $VERSION" "$VERSION"

echo "Script completed successfully"
EOF
    
    chmod +x test-script.sh
    
    # Run the script
    script_output=$(./test-script.sh 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if tag_exists "v2.5.0"; then
            pass_test "Existing scripts work without modification"
        else
            fail_test "Script didn't create expected tag"
        fi
    else
        fail_test "Script compatibility broken: $script_output"
    fi
    
    rm -f test-script.sh
}

test_parameter_parsing_compatibility() {
    start_test "Parameter parsing maintains compatibility"
    
    cd "$INTEGRATION_TEST_REPO_DIR"
    cleanup_release_branches
    
    # Test various parameter combinations
    test_cases=(
        "3.0.0"                    # Simple version
        "3.0.0 develop"           # Version with base branch
        "--fetch 3.1.0"           # Flag before version
        "3.2.0 --fetch"           # Invalid: flag after version (should fail gracefully)
    )
    
    passed=0
    total=${#test_cases[@]}
    
    for test_case in "${test_cases[@]}"; do
        cleanup_release_branches
        
        # Run test case
        eval "git flow release start $test_case" >/dev/null 2>&1
        exit_code=$?
        
        if [ "$test_case" = "3.2.0 --fetch" ]; then
            # This should fail
            if [ $exit_code -ne 0 ]; then
                passed=$((passed + 1))
            fi
        else
            # These should succeed
            if [ $exit_code -eq 0 ]; then
                passed=$((passed + 1))
            fi
        fi
    done
    
    if [ $passed -eq $total ]; then
        pass_test "Parameter parsing maintains full compatibility"
    else
        fail_test "Parameter parsing compatibility issues: $passed/$total cases passed"
    fi
}

#
# Test Runner
#

run_integration_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Integration & Regression Tests      ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    setup_integration_repo
    
    # Regression Tests
    echo -e "\n${YELLOW}Regression Tests - Existing Functionality${NC}"
    test_traditional_release_workflow
    test_feature_workflow_unchanged
    test_hotfix_workflow_unchanged
    
    # Integration Tests
    echo -e "\n${YELLOW}Integration Tests - New Feature Integration${NC}"
    test_auto_version_after_hotfix
    test_mixed_workflow_compatibility
    test_concurrent_branch_operations
    
    # Configuration Tests
    echo -e "\n${YELLOW}Configuration & Environment Tests${NC}"
    test_different_branch_names
    test_remote_repository_integration
    
    # Backwards Compatibility
    echo -e "\n${YELLOW}Backwards Compatibility Tests${NC}"
    test_script_compatibility
    test_parameter_parsing_compatibility
    
    cleanup_integration_repo
    
    # Test Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}      Integration Test Summary           ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Integration Tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}All integration tests passed! ✅${NC}"
        return 0
    else
        echo -e "\n${RED}Some integration tests failed! ❌${NC}"
        return 1
    fi
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_integration_tests
    exit $?
fi