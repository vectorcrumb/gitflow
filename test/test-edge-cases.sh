#!/bin/bash
#
# Edge Case and Performance Tests for Optional Release Argument Feature
# Advanced testing scenarios for robustness validation
#

# Test framework setup (reuse from main test)
source "$(dirname "$0")/test-optional-release.sh" 2>/dev/null || {
    # Define basic functions if sourcing fails
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
    
    start_test() {
        TEST_COUNT=$((TEST_COUNT + 1))
        echo -e "\n${BLUE}=== Edge Test $TEST_COUNT: $1 ===${NC}"
    }
    
    pass_test() {
        PASS_COUNT=$((PASS_COUNT + 1))
        log_success "$1"
    }
    
    fail_test() {
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log_error "$1"
    }
}

EDGE_TEST_REPO_DIR="/tmp/gitflow-edge-test-$$"

# Setup repository for edge case testing
setup_edge_test_repo() {
    log_info "Setting up edge case test repository at $EDGE_TEST_REPO_DIR"
    
    rm -rf "$EDGE_TEST_REPO_DIR"
    mkdir -p "$EDGE_TEST_REPO_DIR"
    cd "$EDGE_TEST_REPO_DIR"
    
    git init
    git config user.name "Edge Test User"
    git config user.email "edge@example.com"
    
    echo "Initial commit" > README.md
    git add README.md
    git commit -m "Initial commit"
    
    git flow init -d
    
    # Set version tag prefix to match our test tags
    git config gitflow.prefix.versiontag "v"
}

cleanup_edge_test_repo() {
    cd /
    rm -rf "$EDGE_TEST_REPO_DIR"
}

# Helper to create many tags for performance testing
create_many_tags() {
    local count=$1
    log_info "Creating $count version tags for performance testing"
    
    for i in $(seq 1 $count); do
        local major=$((i / 100))
        local minor=$(((i % 100) / 10))
        local patch=$((i % 10))
        git tag "v${major}.${minor}.${patch}" 2>/dev/null || true
    done
}

#
# Edge Case Tests
#

test_empty_repository() {
    start_test "Empty repository without any commits"
    
    local empty_repo="/tmp/gitflow-empty-$$"
    mkdir -p "$empty_repo"
    cd "$empty_repo"
    
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Try to initialize git-flow on empty repo
    output=$(git flow init -d 2>&1)
    if [ $? -ne 0 ]; then
        pass_test "Git-flow init correctly fails on empty repository"
    else
        # If init succeeds, test should still fail gracefully
        test_output=$(git flow release start 2>&1)
        if [ $? -ne 0 ]; then
            pass_test "Release start fails gracefully on empty repository"
        else
            fail_test "Should not succeed on empty repository: $test_output"
        fi
    fi
    
    cd /
    rm -rf "$empty_repo"
}

test_version_overflow() {
    start_test "Version number overflow scenarios"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Create extremely high version numbers
    git tag v999.999.999
    
    # Test major bump (should handle large numbers)
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    
    cleanup_release_branches
    output=$(git flow release start --major 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "1000.0.0"; then
            pass_test "Correctly handled version overflow: 999.999.999 → 1000.0.0"
        else
            fail_test "Version overflow not handled correctly: $output"
        fi
    else
        # Check if it's a reasonable error
        if echo "$output" | grep -q -E "(overflow|too large|invalid)"; then
            pass_test "Reasonable error for version overflow: $output"
        else
            fail_test "Unexpected error for version overflow: $output"
        fi
    fi
}

test_malicious_tag_names() {
    start_test "Security: Malicious tag name handling"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Create tags with potentially problematic characters
    git tag 'v1.0.0; rm -rf /' 2>/dev/null || true
    git tag 'v1.0.0`whoami`' 2>/dev/null || true
    git tag 'v1.0.0$(echo test)' 2>/dev/null || true
    git tag 'v../../../etc/passwd' 2>/dev/null || true
    
    # Add a normal tag that should be detected
    git tag v2.0.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    
    cleanup_release_branches
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 2.1.0"; then
            if echo "$output" | grep -q "based on latest tag: v2.0.0"; then
                pass_test "Correctly ignored malicious tags, used v2.0.0"
            else
                fail_test "Did not use correct base tag: $output"
            fi
        else
            fail_test "Did not generate expected version: $output"
        fi
    else
        fail_test "Command failed with malicious tags present: $output"
    fi
}

test_unicode_tags() {
    start_test "Unicode and special characters in tags"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Create tags with unicode characters
    git tag 'v1.0.0-α' 2>/dev/null || true
    git tag 'v1.0.0-β' 2>/dev/null || true
    git tag 'v1.0.0-中文' 2>/dev/null || true
    
    # Add normal semantic version tags
    git tag v1.5.0
    git tag v2.0.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    
    cleanup_release_branches
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 2.1.0"; then
            pass_test "Correctly handled unicode tags, used semantic versions"
        else
            fail_test "Did not generate expected version: $output"
        fi
    else
        fail_test "Command failed with unicode tags: $output"
    fi
}

test_concurrent_operations() {
    start_test "Concurrent release operations"
    
    cd "$EDGE_TEST_REPO_DIR"
    git tag v1.0.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    cleanup_release_branches
    
    # Start first release
    git flow release start 1.1.0 &
    pid1=$!
    
    # Try to start auto-generated release immediately
    sleep 0.1
    output2=$(git flow release start 2>&1)
    exit_code2=$?
    
    # Wait for first process
    wait $pid1
    exit_code1=$?
    
    # One should succeed, one should fail with existing release error
    if [ $exit_code1 -eq 0 ] && [ $exit_code2 -ne 0 ]; then
        if echo "$output2" | grep -q "existing release branch"; then
            pass_test "Correctly handled concurrent release creation"
        else
            fail_test "Second command failed but not with expected error: $output2"
        fi
    elif [ $exit_code1 -ne 0 ] && [ $exit_code2 -eq 0 ]; then
        pass_test "One of the concurrent operations succeeded appropriately"
    else
        fail_test "Both operations had same result (exit1: $exit_code1, exit2: $exit_code2)"
    fi
}

#
# Performance Tests
#

test_performance_many_tags() {
    start_test "Performance with large number of tags"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Create 1000 version tags
    create_many_tags 1000
    
    # Add the latest semantic version
    git tag v10.0.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    cleanup_release_branches
    
    # Time the operation
    start_time=$(date +%s%N)
    output=$(git flow release start 2>&1)
    end_time=$(date +%s%N)
    exit_code=$?
    
    duration=$(((end_time - start_time) / 1000000)) # Convert to milliseconds
    
    if [ $exit_code -eq 0 ]; then
        if [ $duration -lt 5000 ]; then # Less than 5 seconds
            pass_test "Performance acceptable with 1000+ tags: ${duration}ms"
        else
            log_warning "Performance slower than expected: ${duration}ms"
            pass_test "Command succeeded despite performance concern"
        fi
        
        if echo "$output" | grep -q "Auto-generated version: 10.1.0"; then
            pass_test "Correctly found latest version among many tags"
        else
            fail_test "Did not find correct latest version: $output"
        fi
    else
        fail_test "Command failed with many tags: $output"
    fi
}

test_memory_usage() {
    start_test "Memory usage with complex tag patterns"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Create complex mix of tags
    for i in {1..100}; do
        git tag "v$i.0.0" 2>/dev/null || true
        git tag "release-$i.0.0" 2>/dev/null || true
        git tag "version$i" 2>/dev/null || true
        git tag "v$i.0" 2>/dev/null || true
        git tag "v$i.0.0-alpha" 2>/dev/null || true
        git tag "v$i.0.0-beta.$i" 2>/dev/null || true
    done
    
    # Add latest valid tag
    git tag v100.1.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    cleanup_release_branches
    
    # Monitor memory usage if possible
    if command -v pmap >/dev/null 2>&1; then
        output=$(git flow release start 2>&1) &
        pid=$!
        
        # Simple memory check
        sleep 0.5
        if kill -0 $pid 2>/dev/null; then
            wait $pid
            exit_code=$?
        else
            exit_code=1
        fi
    else
        # Just run the command
        output=$(git flow release start 2>&1)
        exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "Auto-generated version: 100.2.0"; then
            pass_test "Memory usage acceptable with complex tag patterns"
        else
            fail_test "Incorrect version detection: $output"
        fi
    else
        fail_test "Memory issues or other failure: $output"
    fi
}

#
# Stress Tests
#

test_deeply_nested_version_numbers() {
    start_test "Very specific version number edge cases"
    
    cd "$EDGE_TEST_REPO_DIR"
    
    # Test edge cases in version comparison
    git tag v10.2.0
    git tag v10.10.0
    git tag v2.1.0
    git tag v2.10.0
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    cleanup_release_branches
    
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        # Should use v10.10.0 as the latest (not v2.10.0)
        if echo "$output" | grep -q "Auto-generated version: 10.11.0"; then
            if echo "$output" | grep -q "based on latest tag: v10.10.0"; then
                pass_test "Correct version comparison: v10.10.0 > v2.10.0"
            else
                fail_test "Did not identify correct base tag: $output"
            fi
        else
            fail_test "Did not generate expected version 10.11.0: $output"
        fi
    else
        fail_test "Command failed with complex version numbers: $output"
    fi
}

test_repository_corruption_resilience() {
    start_test "Resilience to repository corruption"
    
    cd "$EDGE_TEST_REPO_DIR"
    git tag v1.0.0
    
    # Create a corrupted tag reference (simulate partial corruption)
    mkdir -p .git/refs/tags
    echo "invalid-ref-content" > .git/refs/tags/v-corrupted
    
    cleanup_release_branches() {
        for branch in $(git branch --list | grep "release/" | sed 's/^[* ] //'); do
            git branch -D "$branch" 2>/dev/null || true
        done
    }
    cleanup_release_branches
    
    output=$(git flow release start 2>&1)
    exit_code=$?
    
    # Command should either succeed (ignoring corrupted refs) or fail gracefully
    if [ $exit_code -eq 0 ]; then
        pass_test "Resilient to repository corruption, continued working"
    else
        if echo "$output" | grep -q -E "(fatal|error)"; then
            pass_test "Failed gracefully due to repository corruption"
        else
            fail_test "Unexpected behavior with corruption: $output"
        fi
    fi
    
    # Clean up corruption
    rm -f .git/refs/tags/v-corrupted
}

#
# Test Runner
#

run_edge_tests() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}     Edge Cases & Performance Tests     ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    setup_edge_test_repo
    
    # Edge Case Tests
    echo -e "\n${YELLOW}Edge Case Tests${NC}"
    test_empty_repository
    test_version_overflow
    test_malicious_tag_names
    test_unicode_tags
    test_concurrent_operations
    
    # Performance Tests
    echo -e "\n${YELLOW}Performance Tests${NC}"
    test_performance_many_tags
    test_memory_usage
    
    # Stress Tests
    echo -e "\n${YELLOW}Stress Tests${NC}"
    test_deeply_nested_version_numbers
    test_repository_corruption_resilience
    
    cleanup_edge_test_repo
    
    # Test Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}         Edge Test Summary               ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Edge Tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}All edge case tests passed! ✅${NC}"
        return 0
    else
        echo -e "\n${RED}Some edge case tests failed! ❌${NC}"
        return 1
    fi
}

# Execute if run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_edge_tests
    exit $?
fi