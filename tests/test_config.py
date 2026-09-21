"""
Tests for phubb_free/config.py.
"""

from phubb_free.config import (
    PROJECT_ROOT,
    DATASETS_DIR,
    CNS_BT_FILE,
    STUDENTLIFE_PHONELOCK,
    STUDENTLIFE_BLUETOOTH,
    LJUBLJANA_NOTIFICATIONS,
    LJUBLJANA_SCREEN,
    LJUBLJANA_BLUETOOTH,
    RSSI_COPRESENCE_THRESHOLD,
    FEATURE_WINDOW_SEC,
    APP_SWITCH_GAP_THRESHOLD_SEC,
    USER_PREFIX_CNS,
    USER_PREFIX_STUDENTLIFE,
    USER_PREFIX_LJUBLJANA,
    EVENT_UNLOCK,
    EVENT_APP_SWITCH,
    EVENT_NOTIFICATION,
    EVENT_PROXIMITY,
)


def test_paths_exist():
    assert PROJECT_ROOT.exists(), f"Project root {PROJECT_ROOT} does not exist"
    assert DATASETS_DIR.exists(), f"Datasets dir {DATASETS_DIR} does not exist"
    assert CNS_BT_FILE.exists(), f"CNS file {CNS_BT_FILE} does not exist"
    assert STUDENTLIFE_PHONELOCK.exists(), f"StudentLife phonelock {STUDENTLIFE_PHONELOCK} does not exist"
    assert STUDENTLIFE_BLUETOOTH.exists(), f"StudentLife bluetooth {STUDENTLIFE_BLUETOOTH} does not exist"
    assert LJUBLJANA_NOTIFICATIONS.exists(), f"Ljubljana notifications {LJUBLJANA_NOTIFICATIONS} does not exist"
    assert LJUBLJANA_SCREEN.exists(), f"Ljubljana screen {LJUBLJANA_SCREEN} does not exist"
    assert LJUBLJANA_BLUETOOTH.exists(), f"Ljubljana bluetooth {LJUBLJANA_BLUETOOTH} does not exist"


def test_constants():
    assert RSSI_COPRESENCE_THRESHOLD == -75
    assert FEATURE_WINDOW_SEC == 3600
    assert APP_SWITCH_GAP_THRESHOLD_SEC == 30


def test_user_prefixes():
    prefixes = [USER_PREFIX_CNS, USER_PREFIX_STUDENTLIFE, USER_PREFIX_LJUBLJANA]
    assert len(prefixes) == len(set(prefixes)), "User prefixes must be distinct"
    assert all(isinstance(p, str) and len(p) > 0 for p in prefixes)


def test_event_types():
    event_types = {EVENT_UNLOCK, EVENT_APP_SWITCH, EVENT_NOTIFICATION, EVENT_PROXIMITY}
    assert len(event_types) == 4
