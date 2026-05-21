# 🎮 Game Design Document (Working Draft)

## 🧭 Overview

This game is a **roguelite, score-driven, board strategy game** inspired by Go-like spatial gameplay and modern deckbuilders.

Players place stones on a board, use cards to manipulate the game state, and build synergistic combinations to generate increasingly high scores. The game is structured as a **run-based progression system** with multiple encounters culminating in boss fights.

---

# 🎯 Core Concepts

## Score System
- The game uses two core scoring components:
  - **Points (Base Value)** → analogous to “chips”
  - **Multiplier (Mult)** → amplifies points
- Final score calculation:
  - Score = Points × Multiplier


---

# 🕹️ Single Game Rules

## 🧩 Win Conditions

Different game types may have different win conditions:

- Reach a **target score threshold**
- Have **more score than the opponent** when:
- Out of moves
- Out of stones
- Defeat a specific opponent condition (e.g. boss rules)

---

## 🎴 Player Resources

### 1. Card Deck
- A deck of **playing cards** used during a match
- Cards can be played **before placing a stone**
- Cards cost a resource (see Energy below)

---

### 2. Stone Pouch
- A pool of stones the player draws from
- Stones are placed on the board as the main action

---

### 3. Passive Effects (Working Name: *Poses*)
- Passive abilities active throughout the match
- Equivalent to “relics” / “jokers”
- Define the player’s build and strategy

---

### 4. Energy (Rename Pending)
- Resource used to play cards
- Limits how many actions can be taken before placing a stone

---

## 🔁 Turn Structure

Each turn:

1. Player may:
 - Play any number of cards (limited by energy)
2. Player places **one stone** on the board
3. Scoring is calculated
4. Turn passes to opponent

---

## ⛔ Run Constraints

A match may be limited by:

- Number of **moves**
- Number of **stones available**
- Special rule conditions

---

## 👁️ Information Visibility

- Player can see:
- Opponent **passive effects (Poses)**
- Player cannot see:
- Opponent stones
- Opponent card deck

---

## 👑 Boss Rules

- Boss matches are played **until the end**
- No early win via threshold
- Final winner = player with **higher total score**

---

# 💯 Scoring System

> ⚠️ Note: These rules are flexible and may be reassigned between Points and Multiplier during development.

---

## 🧱 Points (Base Score)

### 1. Liberties
- Primary source of base points
- Stones gain points based on their available liberties

---

### 2. Captures (Prisoners)
- Capturing enemy stones grants points
- Expected to be a **major scoring mechanic**

---

### 3. Board Control (Space)
- Controlling space on the board contributes to scoring
- Especially important in **end-of-game scoring (boss fights)**

---

## ✖️ Multiplier (Scaling)

### 1. Shape-Based Multipliers
- Creating shapes on the board increases multiplier
- Shapes must match **specific stone types**

#### Examples:
- “X” stone forming an X shape
- “Line” stone forming a line
- Other shapes:
- Box
- Triangle
- Chains

- Larger or more complex shapes → higher multiplier

---

## 🧠 Design Principle

- Points = **what you gain**
- Multiplier = **how well you structured it**

Both systems may evolve and overlap during development.

---

# 🌍 Run Structure (Meta Layer)

## 🗺️ Map System

- The game features a **node-based map**
- Inspired by branching progression systems

### Node Types:
- Standard opponents
- Elite enemies / mini-bosses
- Shops
- Boss encounters
- (Optional) Special events

---

## 🛒 Rewards & Acquisition

After battles or in shops, players can acquire:

### Item Types:

#### 1. Passive Effects (Poses)
- Define build identity
- Persistent during a run

---

#### 2. Stones
- Add new stone types to the pouch
- Expand gameplay possibilities

---

#### 3. Playing Cards
- Expand tactical options
- Used during matches

---

#### 4. Stone Modifiers *(Rename Needed)*
- Modify behavior of specific stone types

---

#### 5. Card Modifiers *(Rename Needed)*
- Modify how playing cards behave

---

#### 6. Run Modifiers *(Rename Needed)*
- Affect global rules of the run

---

## 🧬 Run Start (Loadout)

At the beginning of each run:

- Player selects **Permanent Passive Effects (Poses)**
- These are unlocked through progression
- Define starting strategy and build direction

---

# ⚙️ Open Naming Tasks

The following systems need stronger thematic naming:

- Energy → ?
- Permanent Poses → ?
- Stone Modifiers → ?
- Card Modifiers → ?
- Run Modifiers → ?

---

# 🔄 Future Expansion Areas

This document will be expanded with:

- Stone types
- Card designs
- Passive effect system (Poses)
- Modifier systems
- Scoring tuning
- UI/UX flow
- AI behavior

---

# 🧠 Design Goals Summary

- Fast, satisfying scoring loop
- Strong build identity
- High synergy potential
- Skill expression over randomness (in later stages)
- Replayability through system interactions

---