#!/usr/bin/env python3
import json
import os
import sys

def calculate_score(results_dir):
    summary_path = os.path.join(results_dir, 'summary.json')
    if not os.path.exists(summary_path):
        return None, None

    with open(summary_path, 'r') as f:
        summary = json.load(f)

    totals = summary.get('totals', {})
    critical = totals.get('critical', 0)
    high = totals.get('high', 0)
    medium = totals.get('medium', 0)
    low = totals.get('low', 0)

    score = 100
    score -= critical * 25
    score -= high * 10
    score -= medium * 3
    score -= low * 1

    # Bonus for good practices
    if os.path.exists(os.path.join(results_dir, 'sbom-source.spdx.json')):
        score += 5
    
    # We could check for more (cosign signatures, etc.)
    
    score = max(0, min(100, score))
    
    if score >= 95: grade = 'A+'
    elif score >= 85: grade = 'A'
    elif score >= 70: grade = 'B'
    elif score >= 50: grade = 'C'
    elif score >= 25: grade = 'D'
    else: grade = 'F'
    
    return score, grade

def generate_badge_url(score, grade):
    color = 'brightgreen'
    if grade in ['A', 'A+']: color = 'brightgreen'
    elif grade == 'B': color = 'green'
    elif grade == 'C': color = 'yellow'
    elif grade == 'D': color = 'orange'
    else: color = 'red'
    
    label = f"FortressCI-{grade} ({score})"
    label = label.replace(' ', '%20')
    return f"https://img.shields.io/badge/{label}-{color}"

if __name__ == "__main__":
    results_dir = sys.argv[1] if len(sys.argv) > 1 else "./results"
    score, grade = calculate_score(results_dir)
    
    if score is not None:
        badge_url = generate_badge_url(score, grade)
        print(f"🛡️ FortressCI Score: {score} ({grade})")
        print(f"🔗 Badge URL: {badge_url}")
        
        with open(os.path.join(results_dir, 'badge.json'), 'w') as f:
            json.dump({"score": score, "grade": grade, "badge_url": badge_url}, f, indent=2)
    else:
        print("Error: Could not calculate score (summary.json missing).")
