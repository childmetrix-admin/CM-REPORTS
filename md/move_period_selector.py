#!/usr/bin/env python3
"""Move period selector from secondary nav to tertiary nav"""

with open('index.html', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Remove period selector from secondary nav (lines 185-195, 0-indexed 184-194)
# and the closing </nav> adjustment
new_lines = []
skip_lines = set(range(184, 195))  # Lines 185-195 (0-indexed)

for i, line in enumerate(lines):
    if i in skip_lines:
        continue
    new_lines.append(line)

# Now find and replace the tertiary nav section
output = []
i = 0
while i < len(new_lines):
    line = new_lines[i]

    # Find the tertiary nav opening
    if 'id="cfsrTertiaryNav"' in line and 'class="flex items-center px-4' in line:
        # Replace with justify-between version
        output.append(line.replace('class="flex items-center px-4', 'class="flex items-center justify-between px-4'))
        i += 1

        # Add the navigation links div
        output.append(new_lines[i])  # <div class="flex items-center gap-1">
        i += 1

        # Add the three tertiary links
        while i < len(new_lines) and '</div>' not in new_lines[i]:
            output.append(new_lines[i])
            i += 1

        # Add closing </div> for links
        output.append(new_lines[i])
        i += 1

        # Insert period selector before closing </nav>
        output.append('''          <!-- Period selector on the right -->
          <div>
            <label class="text-sm inline-flex items-center gap-2">
              <span>CFSR Profile Period:</span>
              <select id="cfsrPeriodSelect" class="border px-2 py-1 text-sm rounded">
                <option value="2025_02" selected>February 2025</option>
                <option value="2024_08">August 2024</option>
                <option value="2024_02">February 2024</option>
              </select>
            </label>
          </div>
''')

        # Add closing </nav>
        output.append(new_lines[i])
        i += 1
    else:
        output.append(line)
        i += 1

with open('index.html', 'w', encoding='utf-8') as f:
    f.writelines(output)

print("Period selector moved to tertiary nav successfully")
