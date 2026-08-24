#!/usr/bin/env python3
import argparse, csv, json, re, unicodedata
from collections import defaultdict
from pathlib import Path

def ascii_text(value, limit=None):
    value = "" if value is None else str(value)
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"\s+", " ", value).strip()
    if limit:
        value = value[:limit]
    return value

def norm(value):
    return re.sub(r"[^a-z0-9]", "", ascii_text(value).lower())

def cstr(value):
    value = ascii_text(value)
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

def stat_int(row, key):
    try:
        return int(float(row.get(key, 0) or 0))
    except Exception:
        return 0

def signature_from_csv(row):
    return (
        stat_int(row,"RATING"), ascii_text(row.get("POSITION","")).upper(),
        stat_int(row,"PACE"), stat_int(row,"SHOOTING"), stat_int(row,"PASSING"),
        stat_int(row,"DRIBBLING"), stat_int(row,"DEFENDING"), stat_int(row,"PHYSICAL")
    )

def signature_from_special(row):
    def iv(k):
        try:
            return int(float(row.get(k,0) or 0))
        except Exception:
            return 0
    return (iv("RAT"), ascii_text(row.get("POS","")).upper(), iv("PAC"), iv("SHO"), iv("PAS"), iv("DRI"), iv("DEF"), iv("PHY"))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--specials", required=True)
    ap.add_argument("--out-c", required=True)
    ap.add_argument("--out-h", required=True)
    ap.add_argument("--summary", required=True)
    args=ap.parse_args()

    with open(args.specials, encoding="utf-8") as f:
        specials=json.load(f)

    special_map=defaultdict(list)
    for sp in specials:
        special_map[signature_from_special(sp)].append({
            "surname": norm(sp.get("Surname","")),
            "version": ascii_text(sp.get("VER","Special"), 20) or "Special",
        })

    cards=[]
    clubs=set(); leagues=set(); positions=set(); versions=set()
    seen=set()

    with open(args.csv, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            name=ascii_text(row.get("NAME","Unknown"), 36)
            club=ascii_text(row.get("CLUB","Unknown"), 28)
            league=ascii_text(row.get("LEAGUE","Unknown"), 24)
            pos=ascii_text(row.get("POSITION",""), 5).upper()
            tier=ascii_text(row.get("TIER","Gold"), 10).title() or "Gold"
            sig=signature_from_csv(row)
            ver=tier
            nname=norm(name)
            for sp in special_map.get(sig, []):
                if sp["surname"] and (sp["surname"] in nname or nname.endswith(sp["surname"])):
                    ver=sp["version"]
                    break

            rating,pac,sho,pas,dri,deff,phy = sig[0], sig[2], sig[3], sig[4], sig[5], sig[6], sig[7]
            key=(name,club,league,pos,ver,rating,pac,sho,pas,dri,deff,phy)
            if key in seen:
                continue
            seen.add(key)
            cards.append(key)
            clubs.add(club); leagues.add(league); positions.add(pos); versions.add(ver)

    cards.sort(key=lambda x:(-x[5], x[0], x[4]))

    header = '''#ifndef FUT15_DATA_H
#define FUT15_DATA_H

typedef struct {
    const char *name;
    const char *club;
    const char *league;
    const char *position;
    const char *version;
    unsigned char rating, pac, sho, pas, dri, def, phy;
} Fut15Card;

extern const Fut15Card fut15_cards[];
extern const unsigned int fut15_card_count;
extern const unsigned int fut15_club_count;
extern const unsigned int fut15_league_count;
extern const unsigned int fut15_position_count;
extern const unsigned int fut15_special_count;

#endif
'''
    lines=['#include "fut15_data.h"', '', 'const Fut15Card fut15_cards[] = {']
    special_count=0
    base_types={"Gold","Silver","Bronze","Gold_Non-rare"}
    for c in cards:
        name,club,league,pos,ver,rating,pac,sho,pas,dri,deff,phy=c
        if ver not in base_types:
            special_count += 1
        lines.append('    {%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d},' % (
            cstr(name), cstr(club), cstr(league), cstr(pos), cstr(ver),
            rating,pac,sho,pas,dri,deff,phy))
    lines += [
        '};',
        'const unsigned int fut15_card_count = sizeof(fut15_cards)/sizeof(fut15_cards[0]);',
        f'const unsigned int fut15_club_count = {len(clubs)};',
        f'const unsigned int fut15_league_count = {len(leagues)};',
        f'const unsigned int fut15_position_count = {len(positions)};',
        f'const unsigned int fut15_special_count = {special_count};',
        ''
    ]
    Path(args.out_h).write_text(header, encoding="utf-8")
    Path(args.out_c).write_text("\n".join(lines), encoding="utf-8")
    Path(args.summary).write_text(
        "FIFA 15 data build summary\n"
        f"Cards compiled: {len(cards)}\n"
        f"Clubs: {len(clubs)}\nLeagues: {len(leagues)}\nPositions: {len(positions)}\n"
        f"Special-version rows matched: {special_count}\n"
        "Versions: " + ", ".join(sorted(versions)) + "\n"
        "Sources: kafagy/fifa-FUT-Data FIFA15.csv + MateuszMachowina/PackOpenerF15 players.json\n",
        encoding="utf-8")
    print(f"Generated {len(cards)} cards; {special_count} special rows; {len(clubs)} clubs; versions={sorted(versions)}")

if __name__=="__main__":
    main()
