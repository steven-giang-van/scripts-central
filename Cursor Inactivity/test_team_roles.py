#!/usr/bin/env python3
"""
Test script to show team member roles and filtering.
"""

import yaml
import logging
from automated_user_management import CursorAPIClient

def main():
    # Load configuration
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    # Initialize API client
    api_config = config.get('cursor_api', {})
    client = CursorAPIClient(
        api_key=api_config.get('api_key'),
        base_url=api_config.get('base_url', 'https://api.cursor.com')
    )
    
    # Get all members
    all_members = client.get_all_members()
    
    # Analyze roles
    role_counts = {}
    for member in all_members:
        role = member.get('role', 'unknown')
        role_counts[role] = role_counts.get(role, 0) + 1
    
    print("=" * 60)
    print("TEAM MEMBER ROLE BREAKDOWN")
    print("=" * 60)
    print(f"Total members: {len(all_members)}")
    print()
    
    for role, count in sorted(role_counts.items()):
        print(f"{role:15} : {count:3d} members")
    
    print()
    print("=" * 60)
    print("FILTERING RESULTS")
    print("=" * 60)
    
    # Get filtered team members (excluding owners)
    team_members = client.get_team_members()
    print(f"Non-owner members: {len(team_members)}")
    print(f"Excluded owners: {len(all_members) - len(team_members)}")
    
    print()
    print("Non-owner members:")
    for member in team_members:
        print(f"  • {member.get('email', 'Unknown')} ({member.get('role', 'unknown')})")

if __name__ == "__main__":
    main()

