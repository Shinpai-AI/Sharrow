#!/usr/bin/env python3
"""
Sharrow-Data-Export.py

Validiert und ergänzt lokale Trainings-CSV-Dateien im Sharrow-Ordner.
- Standardisiert *_extend.csv/MT5-CSV zu Train-Format: Time;Open;High;Low;Close;Volume
- Optional: Ergänzt ältere Historie per Polygon.io (Config-getrieben)

Aufruf:
  python3 Sharrow-Data-Export.py --config TKB-config.json --dest .
"""
import argparse
import os
import sys
from datetime import datetime
import csv
from typing import List, Tuple, Dict, Optional
import time

try:
    import requests  # network may be restricted at runtime; code remains optional
except Exception:
    requests = None


class Logger:
    """Minimal logger redirecting output into TKB.log while mirroring to stdout."""

    def __init__(self, logfile: str) -> None:
        self.logfile = logfile

    def _write(self, level: str, message: str) -> None:
        timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
        line = f"[{timestamp}] [DTKB:{level}] {message}"
        print(line, flush=True)
        try:
            with open(self.logfile, 'a', encoding='utf-8') as lf:
                lf.write(line + '\n')
        except Exception:
            pass

    def info(self, message: str) -> None:
        self._write('INFO', message)

    def warn(self, message: str) -> None:
        self._write('WARN', message)


LOG = Logger(os.path.join(os.path.dirname(__file__), 'TKB.log'))

PATTERNS = ("_M1.csv", "_M15.csv", "_H1.csv", "_M1_extend.csv", "_M15_extend.csv", "_H1_extend.csv")

def detect_encoding(path: str) -> str:
    try:
        with open(path, 'rb') as fb:
            sig = fb.read(4)
        # UTF-16 LE/BE BOMs
        if sig.startswith(b'\xff\xfe') or sig.startswith(b'\xfe\xff'):
            return 'utf-16'
        if sig.startswith(b'\xef\xbb\xbf'):
            return 'utf-8-sig'
        return 'utf-8'
    except Exception:
        return 'utf-8'

def normalize_to_standard(dest: str) -> Tuple[int, List[str]]:
    """
    Convert *_extend.csv (and plain *_M*.csv) to standard training CSVs:
    Output header: Time;Open;High;Low;Close;Volume (UTF-8)
    Time format: YYYY-MM-DD HH:MM
    """
    produced = 0
    outputs: List[str] = []
    for name in os.listdir(dest):
        if not name.endswith('.csv'):
            continue
        if not any(s in name for s in ('_M1','_M15','_H1')):
            continue
        src_path = os.path.join(dest, name)
        base_name = name.replace('_extend','')
        base_path = os.path.join(dest, base_name)
        # Standardize file in place; bootstrap base once if only _extend exists
        should_bootstrap_base = name.endswith('_extend.csv') and base_name != name and not os.path.isfile(base_path)
        try:
            enc = detect_encoding(src_path)
            with open(src_path, 'r', encoding=enc, newline='') as f:
                reader = csv.reader(f, delimiter=';')
                rows = list(reader)
            if not rows:
                continue
            # header map
            header = [h.strip().lower() for h in rows[0]]
            # find indices
            def idx(colnames):
                for c in colnames:
                    if c in header:
                        return header.index(c)
                return -1
            i_time = idx(['time','datetime','date'])
            i_open = idx(['open'])
            i_high = idx(['high'])
            i_low  = idx(['low'])
            i_close= idx(['close'])
            i_vol  = idx(['volume','tick_volume','vol'])
            if min(i_time,i_open,i_high,i_low,i_close,i_vol) < 0:
                # skip if cannot map
                continue
            out_rows = [('Time','Open','High','Low','Close','Volume')]
            for r in rows[1:]:
                if not r or len(r) <= max(i_time,i_open,i_high,i_low,i_close,i_vol):
                    continue
                t = r[i_time].strip()
                # Accept formats like 2024.07.01 12:34 or 2024-07-01 12:34
                tfmt = '%Y.%m.%d %H:%M' if '.' in t else '%Y-%m-%d %H:%M'
                try:
                    dt = datetime.strptime(t, tfmt)
                    tstd = dt.strftime('%Y-%m-%d %H:%M')
                except Exception:
                    tstd = t
                out_rows.append((tstd, r[i_open], r[i_high], r[i_low], r[i_close], r[i_vol]))
            if len(out_rows) <= 1:
                continue
            with open(src_path, 'w', encoding='utf-8', newline='') as f:
                w = csv.writer(f, delimiter=';')
                w.writerows(out_rows)
            produced += 1
            outputs.append(src_path)
            if should_bootstrap_base:
                with open(base_path, 'w', encoding='utf-8', newline='') as f:
                    w = csv.writer(f, delimiter=';')
                    w.writerows(out_rows)
                outputs.append(base_path)
        except Exception as e:
            LOG.warn(f"normalize failed für {os.path.basename(src_path)}: {e}")
            continue
    return produced, outputs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--config', required=False, default='TKB-config.json')
    ap.add_argument('--dest', required=False, default='.')
    args = ap.parse_args()

    # Load config (optional)
    cfg = {}
    if args.config and os.path.isfile(args.config):
        try:
            import json
            with open(args.config, 'r', encoding='utf-8') as f:
                cfg = json.load(f)
        except Exception:
            cfg = {}

    # Normalize to standard training CSVs (merge/standardize) for all CSVs already in dest
    produced, outputs = normalize_to_standard(args.dest)
    LOG.info(f"Standardized training CSVs produced: {produced}")
    for p in outputs[:5]:
        LOG.info(f"   => {os.path.basename(p)}")

    # Config-driven timeframe & symbol selection
    train_tf = (cfg.get('train') or {}).get('timeframe', 'H1')
    timeframes_cfg = (cfg.get('data_export') or {}).get('timeframes') or [train_tf]
    tfs = sorted({tf.upper() for tf in timeframes_cfg})
    lookback_years = int((cfg.get('data_export') or {}).get('lookback_years', 2))
    cutoff_days = int((cfg.get('data_export') or {}).get('polygon_cutoff_days', 45))
    symbols = list((cfg.get('symbols') or {}).keys())

    # Optional: Online merge via Polygon.io (config-driven)
    poly = (cfg.get('api_settings') or {}).get('polygon') or {}
    api_key = poly.get('api_key','')
    polygon_enabled = bool(api_key and requests is not None and poly.get('enabled', True))
    if not symbols:
        LOG.info("Polygon merge skipped: no symbols in config")
    else:
        if polygon_enabled:
            LOG.info(f"Polygon merge enabled: {len(symbols)} symbols, tfs={tfs}, lookback={lookback_years}y")
        else:
            LOG.info("Polygon merge disabled (missing API key or requests library)")

    rebuilt_count = 0
    polygon_used_count = 0
    for s in symbols:
        for tf in tfs:
            try:
                LOG.info(f"Rebuild start: {s}_{tf}")
                success, used_polygon = merge_polygon_with_extend(
                    args.dest,
                    s,
                    tf,
                    lookback_years,
                    cutoff_days,
                    api_key if polygon_enabled else '',
                    rate_limit=poly.get('rate_limit', 5)
                )
                if success:
                    rebuilt_count += 1
                if used_polygon:
                    polygon_used_count += 1
            except Exception as e:
                LOG.warn(f"rebuild failed {s}_{tf}: {e}")
                continue

    LOG.info(f"Series rebuilt: {rebuilt_count} (polygon used: {polygon_used_count})")

    # Minimum coverage validation (always run)
    verify_min_coverage(args.dest, symbols, tfs, lookback_years)
    return 0

# ===== Polygon merge helpers =====
def timeframe_map(tf: str) -> Tuple[int,str]:
    t = tf.upper()
    if t == 'M1': return 1, 'minute'
    if t == 'M15': return 15, 'minute'
    if t == 'H1': return 1, 'hour'
    if t == 'H4': return 4, 'hour'
    if t == 'D1': return 1, 'day'
    return 1, 'minute'

def guess_asset_type(symbol: str) -> str:
    s = symbol.upper()
    if len(s) == 6 and s.isalpha():
        return 'FOREX'
    if any(x in s for x in ('BTC','ETH','XRP','ADA','SOL','LTC')):
        return 'CRYPTO'
    if any(x in s for x in ('XAU','XAG','XPT','XPD')):
        return 'METAL'
    return 'OTHER'

def polygon_ticker(symbol: str) -> str:
    at = guess_asset_type(symbol)
    if at == 'FOREX':
        return f"C:{symbol.upper()}"
    if at == 'CRYPTO':
        return f"X:{symbol.upper()}"
    # fallback
    return symbol.upper()

def parse_timestamp(value: str) -> datetime:
    """Parse MT5 (YYYY.MM.DD HH:MM) or standard (YYYY-MM-DD HH:MM) timestamps."""
    value = value.strip()
    if not value:
        raise ValueError("empty timestamp")
    if '.' in value:
        return datetime.strptime(value, '%Y.%m.%d %H:%M')
    return datetime.strptime(value, '%Y-%m-%d %H:%M')


def read_first_time_csv(path: str) -> str:
    try:
        enc = detect_encoding(path)
        with open(path, 'r', encoding=enc, newline='') as f:
            r = csv.reader(f, delimiter=';')
            for i,row in enumerate(r):
                if i == 0: # header
                    continue
                if row and row[0]:
                    return row[0]
    except Exception:
        return ''
    return ''


def read_last_time_csv(path: str) -> str:
    try:
        enc = detect_encoding(path)
        with open(path, 'r', encoding=enc, newline='') as f:
            r = csv.reader(f, delimiter=';')
            last = ''
            for i,row in enumerate(r):
                if i == 0:
                    continue
                if row and row[0]:
                    last = row[0]
            return last
    except Exception:
        return ''
    return ''

def merge_polygon_with_extend(dest_dir: str, symbol: str, tf: str, lookback_years: int, cutoff_days: int, api_key: str, rate_limit: int=5) -> Tuple[bool, bool]:
    std_path = os.path.join(dest_dir, f"{symbol}_{tf}.csv")
    ext_path = os.path.join(dest_dir, f"{symbol}_{tf}_extend.csv")

    now = datetime.utcnow().replace(second=0, microsecond=0)
    required_start = now - timedelta(days=lookback_years * 365)
    required_end = now
    polygon_cutoff = now - timedelta(days=cutoff_days)
    delta = timeframe_delta(tf)

    extend_rows = load_csv_with_dt(ext_path)
    extend_first = extend_rows[0][0] if extend_rows else None

    existing_rows = load_csv_with_dt(std_path)
    existing_first = existing_rows[0][0] if existing_rows else None
    existing_last = existing_rows[-1][0] if existing_rows else None
    existing_dates = {dt for dt, _ in existing_rows}

    polygon_ranges: List[Tuple[datetime, datetime]] = []

    def add_range(start: Optional[datetime], end: Optional[datetime]) -> None:
        if start is None or end is None:
            return
        if end <= start:
            return
        polygon_ranges.append((start.replace(second=0, microsecond=0), end.replace(second=0, microsecond=0)))

    if existing_first is None:
        add_range(required_start, polygon_cutoff)
    else:
        if existing_first > required_start:
            backfill_end = min(existing_first - delta, polygon_cutoff)
            add_range(required_start, backfill_end)
        if existing_last is None or existing_last < polygon_cutoff:
            gap_start = (existing_last + delta) if existing_last else required_start
            add_range(gap_start, polygon_cutoff)

    if extend_first and existing_last and extend_first > existing_last + delta:
        gap_end = min(extend_first - delta, polygon_cutoff)
        add_range(existing_last + delta, gap_end)

    polygon_rows: List[Tuple[str, str, str, str, str, str]] = []
    polygon_used = False
    if api_key and requests is not None and polygon_ranges:
        polygon_ranges.sort(key=lambda r: r[0])
        merged_ranges: List[Tuple[datetime, datetime]] = []
        for start, end in polygon_ranges:
            if not merged_ranges:
                merged_ranges.append((start, end))
                continue
            last_start, last_end = merged_ranges[-1]
            if start <= last_end + delta:
                merged_ranges[-1] = (last_start, max(last_end, end))
            else:
                merged_ranges.append((start, end))

        for start, end in merged_ranges:
            fetch_end = min(end, polygon_cutoff)
            if fetch_end <= start:
                continue
            LOG.info(f"{symbol}_{tf}: Polygon fetch {start:%Y-%m-%d} → {fetch_end:%Y-%m-%d}")
            try:
                fetched = fetch_polygon_rows(symbol, tf, start, fetch_end, api_key, rate_limit)
            except Exception as exc:
                LOG.warn(f"{symbol}_{tf}: Polygon fetch failed ({exc})")
                fetched = []
            if fetched:
                polygon_rows.extend(fetched)
        polygon_used = bool(polygon_rows)
        if polygon_used:
            LOG.info(f"{symbol}_{tf}: Polygon rows fetched {len(polygon_rows)}")
    elif polygon_ranges:
        LOG.info(f"{symbol}_{tf}: Polygon skip – API nicht verfügbar")

    combined: Dict[datetime, List[str]] = {}

    if polygon_rows:
        for row in polygon_rows:
            try:
                dt = parse_timestamp(row[0])
            except Exception:
                continue
            if dt < required_start or dt > required_end:
                continue
            combined[dt] = [dt.strftime('%Y-%m-%d %H:%M')] + list(row[1:6])

    for dt, row in existing_rows:
        if dt < required_start or dt > required_end:
            continue
        combined[dt] = row

    for dt, row in extend_rows:
        if dt < polygon_cutoff:
            continue
        if dt < required_start or dt > required_end:
            continue
        combined[dt] = row

    if not combined:
        LOG.warn(f"{symbol}_{tf}: keine Daten verfügbar (Polygon + MT5 leer)")
        if os.path.isfile(std_path):
            os.remove(std_path)
        return False, polygon_used

    sorted_dt = sorted(combined.keys())
    with open(std_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(['Time','Open','High','Low','Close','Volume'])
        for dt in sorted_dt:
            writer.writerow(combined[dt])

    new_dates = [dt for dt in sorted_dt if dt not in existing_dates]
    action = 'Bootstrap' if not existing_rows else 'Update'
    LOG.info(
        f"{symbol}_{tf}: {action} gespeichert ({len(sorted_dt)} Zeilen, +{len(new_dates)} neu, polygon={'yes' if polygon_used else 'no'})"
    )

    success = bool(new_dates)
    return success, polygon_used

from datetime import timedelta


def timeframe_delta(tf: str) -> timedelta:
    t = tf.upper()
    if t == 'M1':
        return timedelta(minutes=1)
    if t == 'M5':
        return timedelta(minutes=5)
    if t == 'M15':
        return timedelta(minutes=15)
    if t == 'H1':
        return timedelta(hours=1)
    if t == 'H4':
        return timedelta(hours=4)
    if t == 'D1':
        return timedelta(days=1)
    return timedelta(minutes=1)


def load_csv_with_dt(path: str) -> List[Tuple[datetime, List[str]]]:
    if not os.path.isfile(path):
        return []
    rows: List[Tuple[datetime, List[str]]] = []
    try:
        enc = detect_encoding(path)
        with open(path, 'r', encoding=enc, newline='') as f:
            reader = csv.reader(f, delimiter=';')
            next(reader, None)  # header skip
            for raw in reader:
                if not raw or len(raw) < 6 or not raw[0].strip():
                    continue
                try:
                    dt = parse_timestamp(raw[0])
                except Exception:
                    continue
                rows.append((dt, [dt.strftime('%Y-%m-%d %H:%M')] + raw[1:6]))
    except Exception:
        return []
    rows.sort(key=lambda x: x[0])
    return rows


def verify_min_coverage(dest_dir: str, symbols: List[str], timeframes: List[str], lookback_years: int) -> None:
    """Check that each symbol/timeframe covers at least the configured lookback."""
    if not symbols or not timeframes or lookback_years <= 0:
        return
    now = datetime.utcnow()
    required_start = now - timedelta(days=lookback_years * 365)
    for sym in symbols:
        for tf in timeframes:
            base_path = os.path.join(dest_dir, f"{sym}_{tf}.csv")
            if not os.path.isfile(base_path):
                LOG.warn(f"{sym}_{tf}: Datei fehlt nach Export")
                continue
            first_val = read_first_time_csv(base_path)
            last_val = read_last_time_csv(base_path)
            if not first_val or not last_val:
                LOG.warn(f"{sym}_{tf}: keine Datenzeilen gefunden")
                continue
            try:
                first_dt = parse_timestamp(first_val)
                last_dt = parse_timestamp(last_val)
            except Exception as exc:
                LOG.warn(f"{sym}_{tf}: Zeitstempel nicht lesbar ({exc})")
                continue
            if first_dt > required_start:
                missing_days = (first_dt - required_start).days
                LOG.warn(f"{sym}_{tf}: Zeitraum zu kurz (Start {first_dt:%Y-%m-%d %H:%M}, benötigt ≤ {required_start:%Y-%m-%d}) – fehlt ~{missing_days} Tage")
            if last_dt < now - timedelta(days=1):
                lag_days = (now - last_dt).days
                LOG.warn(f"{sym}_{tf}: endet {last_dt:%Y-%m-%d %H:%M}, Nachlauf {lag_days} Tage")

def _max_chunk_days(mult: int, span: str) -> int:
    if span == 'minute':
        approx_per_day = int((24 * 60) / max(mult, 1))
        return max(1, min(30, 45000 // max(approx_per_day, 1)))
    if span == 'hour':
        approx_per_day = int(24 / max(mult, 1))
        return min(400, max(1, 45000 // max(approx_per_day, 1)))
    if span == 'day':
        return 5000
    return 30


def fetch_polygon_rows(symbol: str, tf: str, start_dt: datetime, end_dt: datetime, api_key: str, rate_limit:int=5) -> List[Tuple[str,str,str,str,str,str]]:
    if requests is None:
        return []
    mult, span = timeframe_map(tf)
    ticker = polygon_ticker(symbol)
    chunk_days = _max_chunk_days(mult, span)
    cur = start_dt
    rows: List[Tuple[str,str,str,str,str,str]] = []
    calls = 0
    session = requests.Session()
    while cur < end_dt:
        to = min(cur + timedelta(days=chunk_days), end_dt)
        url = f"https://api.polygon.io/v2/aggs/ticker/{ticker}/range/{mult}/{span}/{cur.strftime('%Y-%m-%d')}/{to.strftime('%Y-%m-%d')}"
        params = {
            'adjusted': 'true',
            'sort': 'asc',
            'limit': 50000,
            'apiKey': api_key,
        }
        LOG.info(f"{symbol}_{tf}:   chunk {cur.strftime('%Y-%m-%d')} → {to.strftime('%Y-%m-%d')}")

        cursor: Optional[str] = None
        while True:
            query_params = params.copy()
            if cursor:
                query_params['cursor'] = cursor
            resp = session.get(url, params=query_params, timeout=60)
            calls += 1
            if rate_limit>0:
                time.sleep(max(0.0, 60.0/rate_limit))
            if resp.status_code != 200:
                break
            data = resp.json()
            if not isinstance(data, dict) or data.get('status') != 'OK':
                break
            for it in data.get('results', []) or []:
                try:
                    ts = datetime.utcfromtimestamp(it['t']/1000).strftime('%Y-%m-%d %H:%M')
                    o = f"{float(it['o']):.5f}"; h = f"{float(it['h']):.5f}"; l = f"{float(it['l']):.5f}"; c = f"{float(it['c']):.5f}"
                    v = str(int(it.get('v',0) or 0))
                    rows.append((ts,o,h,l,c,v))
                except Exception:
                    continue
            next_url_full = data.get('next_url')
            if next_url_full:
                # polygon returns ...?cursor=XYZ; extract cursor token for next call
                if 'cursor=' in next_url_full:
                    cursor = next_url_full.split('cursor=')[-1]
                else:
                    cursor = next_url_full
            else:
                break
        cur = to
    return rows

if __name__ == '__main__':
    sys.exit(main())
