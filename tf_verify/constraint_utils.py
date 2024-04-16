"""
  Copyright 2020 ETH Zurich, Secure, Reliable, and Intelligent Systems Lab

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
"""


# constraints are in conjunctive normal form (CNF)

import re

def clean_string(string):
    return string.replace('\n', '')

def label_index(label):
    return int(clean_string(label)[1:])

def get_constraints_for_dominant_label(label, failed_labels):
    c = Constraints()
    c.add(Constraint(label, "max"))
    return c

def isfloat(value):
  try:
    float(value)
    return True
  except ValueError:
    return False

def get_constraints_from_file(file):
    constraints = Constraints()
    lines = open(file, 'r').readlines()  # AND

    num_labels = int(lines[0])
    for index in range(1, len(lines)):
        elements = re.split(' +', lines[index])
        i = 0
        labels = []  # OR
        while elements[i].startswith('y'):
            labels.append(label_index(elements[i]))
            i += 1

        constraint = clean_string(elements[i])
        i += 1

        if constraint in ["min", "max", "notmin", "notmax"]:
            constraints.add(Constraint(label, constraint))
        elif constraint in [">", "<", ">=", "<="]:
            if isfloat(elements[i]):
                constraints.add(Constraint(label, constraint, float(elements[i])))
            else:
                constraints.add(Constraint(label, constraint, label_index(elements[i])))

    return constraints

class Constraint:
    INVERT_MAP = {
        "min": "notmin",
        "max": "notmax",
        "notmin": "min",
        "notmax": "max",
        ">": "<=",
        "<": ">=",
        ">=": "<",
        "<=": ">"
    }
    F = {
        ">": lambda a, b: a > b,
        "<": lambda a, b: a < b,
        ">=": lambda a, b: a >= b,
        "<=": lambda a, b: a <= b,
    }
    def __init__(self, labels, constraint, other=None):
        self.vnnlib = False
        self.other_const = False
        if other is not None:
            if other.endswith("f"):
                other = float(other[:-1])
                self.other_const = True
            elif "." in other:
                other = float(other)
                self.other_const = True
            else:
                other = int(other)

        if len(labels) == 0:
            raise ValueError("Every constraint requires at least one label")
        if constraint in ["min", "max", "notmin", "notmax"]:
            if other is not None:
                raise ValueError("Min/max constraints should be of the format `<labels> [not]<min|max>`")
            self.vnnlib = True
        elif constraint in [">", "<", ">=", "<="]:
            if other is None or len(labels) == 0:
                raise ValueError("Greater/less than constraints require a label on the left and a label or value on the right")
            if len(labels) > 1:
                raise ValueError("Greater/less than constraints can only have one label")
            if (self.other_const and constraint == ">=") or (not self.other_const and constraint in [">", "<"]):
                self.vnnlib = True
        else:
            raise ValueError(f"Bad constraint `{constraint}`")

        self.repr = " ".join(list(map(lambda n: f"y{int(n)}", labels))) + " " + constraint
        if self.other_const:
            self.repr += " " + str(other)
        elif other is not None:
            self.repr += f" y{int(other)}"

        self.labels = labels
        self.constraint = constraint
        self.other = other

    def __invert__(self):
        return Constraint(self.labels, INVERT_MAP[self.constraint], other=self.other)

    def is_vnnlib(self, force=False):
        if self.constraint == ">=" and not force:
            return False
        if self.other is not None:
            if self.constraint == "<=" and type(self.other) is not float:
                return False
            if self.constraint != "<=" and type(self.other) is float:
                return False
        return True

    def force_vnnlib(self):
        if self.is_vnnlib():
            return self
        elif not self.is_vnnlib(force=True):
            raise ValueError(f"Cannot convert constraint `{self.repr}` to vnnlib format")
        return Constraint(self.labels, self.constraint.replace("=", ""), other=other)


    def __repr__(self):
        return self.repr

    def percent_true(self, lower_bound, upper_bound):
        if self.constraint in ["min", "max", "notmin", "notmax"]:
            chosen = self.labels
            unchosen = list(filter(lambda x: x not in chosen, range(len(lower_bound))))

            f = max if "max" in self.constraint else min

            chosen_low = f(map(lambda x: lower_bound[x], chosen))
            chosen_high = f(map(lambda x: upper_bound[x], chosen))
            unchosen_low = f(map(lambda x: lower_bound[x], unchosen))
            unchosen_high = f(map(lambda x: upper_bound[x], unchosen))

            print(self.constraint)
            print("chosen_low", chosen_low)
            print("chosen_high", chosen_high)
            print("unchosen_low", unchosen_low)
            print("unchosen_high", unchosen_high)

            # Switching the chosen and unchosen highs and lows, and using max, is logically equivalent to using min
            if "min" in self.constraint:
                chosen_low, chosen_high, unchosen_low, unchosen_high = unchosen_low, unchosen_high, chosen_low, chosen_high

            # ALWAYS a max: low >= high
            if chosen_low >= unchosen_high:
                result = 1
            # SOMETIMES a max: high >= low
            elif chosen_high >= unchosen_low:
                range_chosen = chosen_high - chosen_low
                range_unchosen = unchosen_high - unchosen_low
                overlap = chosen_high - unchosen_low
                result = (overlap / range_chosen) * (overlap / range_unchosen)
            # NEVER a max
            else:
                result = 0

            if "not" in self.constraint:
                return 1 - result
            return result

        elif self.constraint in [">", "<", ">=", "<="]:
            v1_low = lower_bound[self.labels[0]]
            v1_high = upper_bound[self.labels[0]]
            if not self.other_const:
                v2_low = lower_bound[self.other]
                v2_high = upper_bound[self.other]
            else:
                v2_low = self.other
                v2_high = self.other

            # Invert less-than so we only have to check once (keep `=`, if present)
            if self.constraint[0] == "<":
                v1_low, v1_high, v2_low, v2_high = v2_low, v2_high, v1_low, v1_high
            f = Constraint.F[self.constraint.replace("<", ">")]

            # ALL greater: low >(=) high
            if f(v1_low, v2_high):
                return 1
            # SOME greater: high >(=) low
            elif f(v1_high, v2_low):
                v1_range = v1_high - v1_low
                v2_range = v2_high - v2_low
                overlap = v1_high - v2_low
                return (overlap / v1_range) * (overlap / v2_range)
            # NONE greater
            else:
                return 0

    def __call__(self, values, upper_bound=None, min_percent=None):
        if upper_bound is not None:
            percent = self.percent_true(values, upper_bound)
            if min_percent is None:
                return percent
            return percent >= min_percent

        elif self.constraint in ["min", "max", "notmin", "notmax"]:
            invert = "not" in self.constraint
            f = np.argmax if "max" in self.constraint else np.argmin
            result = f(values) in self.labels
            if invert:
                return not result
            return result

        elif self.constraint in [">", "<", ">=", "<="]:
            v1 = values[self.labels[0]]
            v2 = self.other
            if not self.other_const:
                v2 = values[v2]
            return Constraint.F[self.constraint](v1, v2)

class Constraints:
    @classmethod
    def from_text(cls, text):
        c = cls()
        if type(text) is str:
            text = text.split("\n")
        for line in text:
            parts = line.split(" ")
            labels = []
            i = 0
            while parts[i] not in Constraint.INVERT_MAP:
                labels.append(parts[i])
                i += 1
            if len(parts) == i + 1: # constraint is last element
                c.add(Constraint(labels, parts[i]))
            else:
                c.add(Constraint(labels, parts[i], parts[i+1]))
        return c
    @classmethod
    def from_constraint_file(cls, file):
        with open(file, 'r') as f:
            lines = f.readlines()
        return cls.from_text(lines)
    @classmethod
    def from_label(cls, label):
        c = cls()
        c.add(Constraint(label, "max"))
        return c


    def __init__(self):
        self.constraints = []

    def add(self, *constraints):
        self.constraints.extend(constraints)

    def is_vnnlib(self, force=False):
        for constraint in self.constraints:
            if not constraint.is_vnnlib(force=force):
                return False
        return True

    def force_vnnlib(self):
        c = Constraints()
        for constraint in self.constraints:
            c.add(constraint.force_vnnlib())
        return c

    def __invert__(self):
        c = Constraints()
        for constraint in self.constraints:
            c.add(~constraint)
        return c

    def __repr__(self):
        return '\n'.join(map(repr, self.constraints))

    def __call__(self, values, upper_bound=None, min_percent=None):
        if upper_bound is None:
            for constraint in self.constraints:
                if not constraint(values):
                    return False
            return True
        elif len(self.constraints) == 0:
            return 1
        elif min_percent is not None:
            for constraint in self.constraints:
                if not constraint(values, upper_bound, min_percent=min_percent):
                    return False
            return True
        else:
            total = 0
            for constraint in self.constraints:
                total += constraint.percent_true(values, upper_bound)
            else:
                return total / len(self.constraints)


