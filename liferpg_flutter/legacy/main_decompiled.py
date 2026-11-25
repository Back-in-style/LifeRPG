# Source Generated with Decompyle++
# File: main.pyc (Python 3.11)

import json
import logging
import os
from datetime import datetime, date
from kivy.clock import Clock
from kivy.core.text import LabelBase
from kivy.lang import Builder
from kivy.metrics import dp
from kivy.properties import StringProperty, NumericProperty, ListProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.widget import Widget
from kivymd.app import MDApp
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.button import MDFlatButton, MDRaisedButton, MDFloatingActionButton
from kivymd.uix.card import MDCard
from kivymd.uix.dialog import MDDialog
from kivymd.uix.label import MDLabel
from kivymd.uix.list import MDList, TwoLineListItem, ThreeLineListItem, OneLineListItem
from kivymd.uix.menu import MDDropdownMenu
from kivymd.uix.progressbar import MDProgressBar
from kivymd.uix.screen import MDScreen
from kivymd.uix.scrollview import MDScrollView
from kivymd.uix.slider import MDSlider
from kivymd.uix.snackbar import Snackbar
from kivymd.uix.textfield import MDTextField
from kivymd.uix.toolbar import MDTopAppBar
from kivymd.uix.bottomnavigation import MDBottomNavigation, MDBottomNavigationItem
from kivymd.uix.selectioncontrol import MDCheckbox
from kivymd.uix.chip import MDChip
APP_NAME = 'LifeRPG'
STAT_KEYS = [
    '힘',
    '민첩',
    '정신력',
    '지구력']
CATEGORY_TO_TREE = {
    'Gym': 'physical',
    'Swim': 'physical',
    'Mobility': 'physical',
    'Recovery': 'physical' }
DAILY_GROUPS = [
    ('grp_dayA', '🅰️ Day A — 등·하체·삼두'),
    ('grp_dayB', '🅱️ Day B — 가슴·어깨·이두'),
    ('grp_core', '🔄 코어'),
    ('grp_swim', '🌊 수영 데이'),
    ('grp_study', '📚 학업'),
    ('grp_routine', '🌙 루틴'),
    ('grp_etc', '📦 기타 Daily')]
STUDY_KEYWORDS = ('강의', '복습', '과제', '집중', '공부')
ROUTINE_KEYWORDS = ('기상', '취침', '식단')
DIFFICULTY_MULTIPLIER = {
    'Easy': 0.7,
    'Normal': 1,
    'Hard': 1.5 }
GRADE_COLORS_HEX = {
    'S': '#FFD700',
    'A': '#8A2BE2',
    'B': '#1E90FF',
    'C': '#32CD32',
    'D': '#808080' }
ACHIEVEMENT_DEFS = [
    {
        'id': 'first_quest',
        'name': '첫 발걸음',
        'desc': '첫 번째 퀘스트를 완료했다!',
        'icon': '🏁' },
    {
        'id': 'first_levelup',
        'name': '각성',
        'desc': '첫 레벨업을 달성했다!',
        'icon': '⚡' },
    {
        'id': 'quest_10',
        'name': '모험가',
        'desc': '퀘스트를 10개 완료했다!',
        'icon': '⚔' },
    {
        'id': 'quest_50',
        'name': '영웅',
        'desc': '퀘스트를 50개 완료했다!',
        'icon': '🛡' },
    {
        'id': 'first_breakthrough',
        'name': '한계 돌파',
        'desc': '첫 돌파 퀘스트를 완료했다!',
        'icon': '💥' },
    {
        'id': 'stat_max_d',
        'name': 'D랭크 달성',
        'desc': '스탯 하나가 상한에 도달했다!',
        'icon': '📊' },
    {
        'id': 'level_5',
        'name': '숙련자',
        'desc': '메인 레벨 5를 달성했다!',
        'icon': '🌟' },
    {
        'id': 'level_10',
        'name': '전문가',
        'desc': '메인 레벨 10을 달성했다!',
        'icon': '✨' }]

def get_daily_group(quest):
    pass
# WARNING: Decompyle incomplete


def rewards_to_text(rewards):
    if not isinstance(rewards, dict):
        return '-'
    parts = None
    for k in ('힘', '민첩', '정신력', '지구력'):
        if not rewards.get(k, 0):
            v = float(0)
            if v != 0:
                sign = '+' if v > 0 else ''
                parts.append(f'''{k}{sign}{v:g}''')
        if 'unlock_stat' in rewards and 'unlock_to' in rewards:
            parts.append(f'''돌파({rewards['unlock_stat']} 상한 {rewards['unlock_to']:g})''')
    return ' / '.join(parts) if parts else '-'


def grade_from_cap(cap_value):

    try:
        cap = float(cap_value)
    except:
        cap = 30

    if cap <= 30:
        return 'D'
    if None <= 50:
        return 'C'
    if None <= 100:
        return 'B'
    if None <= 200:
        return 'A'


def clamp_to_cap(cur, delta, cap_value):
    if delta == 0:
        return (cur, 0)
    cap = None(cap_value)
    target = cur + delta
    if target <= cap:
        return (target, delta)
    applied = None(0, cap - cur)
    return (cap, applied)


def tree_xp_to_next_level(tree, level):
    return 200 + (level - 1) * 80


def compute_tree_level(tree, total_xp):
    level = 1
    xp_left = total_xp
    need = tree_xp_to_next_level(tree, level)
    if xp_left >= need:
        xp_left -= need
        level += 1

    continue
    return (level, xp_left, tree_xp_to_next_level(tree, level))


def now_str():
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def today_str():
    return date.today().isoformat()


def calc_dday(deadline_str):
    if not deadline_str:
        return ''

    try:
        dl = datetime.strptime(deadline_str, '%Y-%m-%d').date()
        diff = (dl - date.today()).days
        if diff > 0:
            return f'''D-{diff}'''
        if None == 0:
            return 'D-Day!'
        return f'''{abs(diff)}'''
    except:
        return ''



class GameStore:

    def __init__(self, data_dir):
        self.data_dir = data_dir
        os.makedirs(data_dir, exist_ok = True)
        self.profile_path = os.path.join(data_dir, 'profile.json')
        self.quests_path = os.path.join(data_dir, 'quests.json')
        self.log_path = os.path.join(data_dir, 'log.json')
        self.achievements_path = os.path.join(data_dir, 'achievements.json')
        self.profile = self._load(self.profile_path, self._default_profile())
        self.quests_data = self._load(self.quests_path, {
            'quests': [],
            'next_id': 1 })
        self.logs_data = self._load(self.log_path, {
            'events': [] })
        self.achievements = self._load(self.achievements_path, {
            'unlocked': [] })
        self._migrate_profile()
        self._rollover_daily_if_needed()
        self._recompute_levels()


    def _default_profile(self):
        return {
            'app': APP_NAME,
            'trees': {
                'physical': {
                    'xp': 0,
                    'level': 1,
                    'xp_in_level': 0,
                    'xp_next': 200 } },
            'main_level': 1,
            'today_date': today_str(),
            'today_xp': 0,
            'stats': {
                '힘': 10,
                '민첩': 10,
                '정신력': 10,
                '지구력': 10 },
            'stat_caps': {
                '힘': 30,
                '민첩': 30,
                '정신력': 30,
                '지구력': 30 },
            'traits': { },
            'streak_days': 0,
            'last_active_date': None }


    def _migrate_profile(self):
        if not isinstance(self.profile.get('stats'), dict):
            self.profile['stats'] = self._default_profile()['stats']
        st = self.profile['stats']
        old_keys = set(st.keys())
        if not old_keys.issuperset({
            'charm',
            'focus',
            'communication'}) and old_keys.intersection(set(STAT_KEYS)):
            self.profile['stats'] = {
                '힘': 10,
                '민첩': 10,
                '정신력': 10,
                '지구력': 10 }
        else:
            for k in STAT_KEYS:
                self.profile['stats'].setdefault(k, 10)
                if not isinstance(self.profile.get('stat_caps'), dict):
                    self.profile['stat_caps'] = { }
        for k in STAT_KEYS:
            self.profile['stat_caps'].setdefault(k, 30)
            if 'trees' not in self.profile:
                self.profile['trees'] = { }
        if 'physical' not in self.profile['trees']:
            self.profile['trees']['physical'] = {
                'xp': 0,
                'level': 1,
                'xp_in_level': 0,
                'xp_next': 200 }
        self.profile.setdefault('main_level', 1)


    def _load(self, path, default):

        try:
            if os.path.exists(path):
                f = open(path, 'r', encoding = 'utf-8')

                try:
                    None(None, None)
                    return
                    with None:
                        if not None, json.load(f):

                            try:

                                try:
                                    pass
                                except Exception:
                                    pass

                                return default





    def save_all(self):
        for path, obj in ((self.profile_path, self.profile), (self.quests_path, self.quests_data), (self.log_path, self.logs_data), (self.achievements_path, self.achievements)):
            tmp = path + '.tmp'
            f = open(tmp, 'w', encoding = 'utf-8')
            json.dump(obj, f, ensure_ascii = False, indent = 2)
            None(None, None)
        with None:
            if not None:
                pass
        os.replace(tmp, path)
        continue


    def log(self, event_type, message, meta = (None,)):
        pass
    # WARNING: Decompyle incomplete


    def _rollover_daily_if_needed(self):
        today = today_str()
        if self.profile.get('today_date') == today:
            return None
        self.profile['today_date'] = None
        self.profile['today_xp'] = 0
        for q in self.quests_data.get('quests', []):
            if q.get('type') == 'Daily':
                q['status'] = 'ACTIVE'
                q['completed_at'] = None
            self.log('system', f'''일일 퀘스트 초기화: {today}''')
            self.save_all()
            return None


    def _recompute_levels(self):
        t = self.profile['trees']['physical']
        (lvl, xp_in, xp_next) = compute_tree_level('physical', int(t.get('xp', 0)))
        t['level'] = lvl
        t['xp_in_level'] = xp_in
        t['xp_next'] = xp_next
        total = (lambda .0: pass# WARNING: Decompyle incomplete
)(self.profile.get('trees', { }).values()())
        self.profile['main_level'] = max(1, total)


    def grant_tree_xp(self, tree_name, amount, reason):
        if amount <= 0:
            return False
        tree = None.profile['trees'].get(tree_name)
        if not tree:
            return False
        before = None(tree.get('level', 1))
        tree['xp'] = int(tree.get('xp', 0)) + int(amount)
        self.profile['today_xp'] = int(self.profile.get('today_xp', 0)) + int(amount)
        self._recompute_levels()
        after = int(self.profile['trees'][tree_name].get('level', 1))
        self.log('xp', f'''{tree_name.upper()} XP +{amount}: {reason}''')
        if after > before:
            self.log('system', f'''{tree_name.upper()} 레벨업! Lv.{before} → Lv.{after}''')
        self.save_all()
        return after > before


    def add_quest(self, title, qtype, desc, category, xp, difficulty, deadline, rewards, unlock_stat, unlock_to = (None, None)):
        qid = self.quests_data.get('next_id', 1)
        self.quests_data['next_id'] = qid + 1
        if not deadline:
            quest = {
                'id': qid,
                'category': category,
                'type': qtype,
                'title': title,
                'xp': 0,
                'rewards': { },
                'difficulty': difficulty,
                'deadline': None,
                'progress': 0,
                'status': 'ACTIVE',
                'created_at': now_str(),
                'completed_at': None,
                'desc': desc }
            if qtype == '돌파':
                quest['unlock_stat'] = unlock_stat
                quest['unlock_to'] = unlock_to
                quest['rewards'] = {
                    'unlock_stat': unlock_stat,
                    'unlock_to': unlock_to }
                self.log('quest', f'''돌파 퀘스트 추가: {title}''')
            else:
                mult = DIFFICULTY_MULTIPLIER.get(difficulty, 1)
                adj_xp = max(1, int(xp * mult))
                quest['xp'] = adj_xp
                quest['base_xp'] = xp
                quest['rewards'] = rewards
                self.log('quest', f'''퀘스트 추가: [{qtype}] {title} (+{adj_xp}XP, {difficulty})''')
        self.quests_data['quests'].append(quest)
        self.save_all()
        return quest


    def complete_quest(self, qid):
        q = self.find_quest(qid)
        if not q:
            return (None, '퀘스트를 찾지 못했음')
        if None.get('status') == 'DONE':
            return (None, '이미 완료된 퀘스트임')
        q['status'] = None
        q['completed_at'] = now_str()
        self.log('quest', f'''퀘스트 완료: {q.get('title', '')}''')
        result = {
            'leveled_up': False,
            'breakthrough': None,
            'stat_gains': [] }
        if q.get('type') == '돌파':
            stat = q.get('unlock_stat')
            unlock_to = q.get('unlock_to')
            if stat in STAT_KEYS and isinstance(unlock_to, (int, float)):
                old_cap = float(self.profile['stat_caps'].get(stat, 30))
                new_cap = float(unlock_to)
                if new_cap > old_cap:
                    self.profile['stat_caps'][stat] = new_cap
                    self.log('breakthrough', f'''돌파 성공: {stat} 상한 {old_cap} → {new_cap}''')
                    result['breakthrough'] = {
                        'stat': stat,
                        'old_cap': old_cap,
                        'new_cap': new_cap,
                        'success': True }
                else:
                    result['breakthrough'] = {
                        'stat': stat,
                        'old_cap': old_cap,
                        'new_cap': new_cap,
                        'success': False }
            else:
                category = q.get('category', 'Other')
                mapped_tree = CATEGORY_TO_TREE.get(category)
                if mapped_tree:
                    leveled_up = self.grant_tree_xp(mapped_tree, int(q.get('xp', 0)), f'''퀘스트: {q.get('title', '')}''')
                    result['leveled_up'] = leveled_up
                rewards = q.get('rewards', { })
                if isinstance(rewards, dict):
                    for sk in STAT_KEYS:
                        if not rewards.get(sk, 0):
                            delta = float(0)
                            if delta == 0:
                                continue
                        cur = float(self.profile['stats'].get(sk, 0))
                        cap = float(self.profile['stat_caps'].get(sk, 30))
                        (new_v, applied) = clamp_to_cap(cur, delta, cap)
                        self.profile['stats'][sk] = round(new_v, 3)
                        if applied > 0:
                            result['stat_gains'].append(f'''+{applied:g} {sk}''')
                            self.log('stat', f'''스탯 상승: {sk} +{applied:g}''')
                        self._recompute_levels()
                        self.save_all()
                        new_achievements = self._check_achievements()
                        result['new_achievements'] = new_achievements
                        return (result, None)


    def delete_quest(self, qid):
        pass
    # WARNING: Decompyle incomplete


    def update_progress(self, qid, progress):
        q = self.find_quest(qid)
        if q:
            q['progress'] = int(progress)
            self.save_all()
            return None


    def find_quest(self, qid):
        qid_str = str(qid)
        for q in self.quests_data.get('quests', []):
            if str(q.get('id')) == qid_str:

                return None, q
            return None


    def _check_achievements(self):
        pass
    # WARNING: Decompyle incomplete


KV = '\n<StatCard@MDCard>:\n    stat_name: ""\n    stat_value: ""\n    stat_grade: ""\n    grade_color: "#808080"\n    orientation: "vertical"\n    padding: dp(12)\n    spacing: dp(4)\n    radius: [dp(12)]\n    elevation: 2\n    size_hint_y: None\n    height: dp(80)\n\n    MDLabel:\n        text: root.stat_name\n        theme_text_color: "Secondary"\n        font_style: "Caption"\n        size_hint_y: None\n        height: dp(20)\n\n    MDBoxLayout:\n        orientation: "horizontal"\n        spacing: dp(8)\n        size_hint_y: None\n        height: dp(36)\n\n        MDLabel:\n            id: value_label\n            text: root.stat_value\n            font_style: "H6"\n            bold: True\n\n        MDLabel:\n            text: root.stat_grade\n            theme_text_color: "Custom"\n            text_color: root.grade_color\n            font_style: "H6"\n            bold: True\n            size_hint_x: None\n            width: dp(48)\n            halign: "right"\n\n\n<QuestListItem@TwoLineListItem>:\n    quest_id: ""\n    quest_type: ""\n    quest_status: ""\n\n\n<SectionHeader@MDBoxLayout>:\n    title: ""\n    orientation: "horizontal"\n    size_hint_y: None\n    height: dp(36)\n    padding: [dp(16), dp(4), dp(16), dp(4)]\n    md_bg_color: app.theme_cls.primary_color[:-1] + [0.1]\n\n    MDLabel:\n        text: root.title\n        font_style: "Caption"\n        bold: True\n        theme_text_color: "Primary"\n'

class StatusScreen(MDScreen):
    pass
# WARNING: Decompyle incomplete


class QuestsScreen(MDScreen):
    pass
# WARNING: Decompyle incomplete


class LogsScreen(MDScreen):
    pass
# WARNING: Decompyle incomplete


class AddQuestContent(MDBoxLayout):
    pass
# WARNING: Decompyle incomplete


class QuestDetailContent(MDBoxLayout):
    pass
# WARNING: Decompyle incomplete


class LifeRPGApp(MDApp):

    def build(self):
        font_registered = False
        for candidate in (os.path.join(os.path.dirname(__file__), 'NanumGothic.ttf'), os.path.join(os.path.dirname(__file__), 'fonts', 'NanumGothic.ttf')):
            if os.path.exists(candidate):
                LabelBase.register(name = 'Roboto', fn_regular = candidate)
                logging.info(f'''[Font] 한글 폰트 로드: {candidate}''')
                font_registered = True

            if not font_registered:
                android_font = os.path.join(self.user_data_dir, 'NanumGothic.ttf')
                if os.path.exists(android_font):
                    LabelBase.register(name = 'Roboto', fn_regular = android_font)
                    logging.info(f'''[Font] user_data_dir 폰트 로드: {android_font}''')
                    font_registered = True
        if not font_registered:
            logging.warning(f'''[Font] NanumGothic.ttf 를 찾지 못했습니다. 한글이 깨질 수 있습니다.\n  해결법 1) buildozer.spec 과 같은 폴더에 NanumGothic.ttf 를 놓고 재빌드\n  해결법 2) adb push NanumGothic.ttf {self.user_data_dir}/''')
        Builder.load_string(KV)
        self.theme_cls.theme_style = 'Dark'
        self.theme_cls.primary_palette = 'DeepPurple'
        self.theme_cls.accent_palette = 'Amber'
        data_dir = os.path.join(self.user_data_dir, 'data')
        self.store = GameStore(data_dir)
        self._import_legacy_json(data_dir)
        nav = MDBottomNavigation()
        self._status_screen = StatusScreen(self.store, name = 'status')
        status_item = MDBottomNavigationItem(name = 'status', text = '상태창', icon = 'account-circle')
        status_item.add_widget(self._status_screen)
        nav.add_widget(status_item)
        self._quests_screen = QuestsScreen(self.store, name = 'quests')
        quest_item = MDBottomNavigationItem(name = 'quests', text = '퀘스트', icon = 'sword-cross')
        quest_item.add_widget(self._quests_screen)
        nav.add_widget(quest_item)
        self._logs_screen = LogsScreen(self.store, name = 'logs')
        logs_item = MDBottomNavigationItem(name = 'logs', text = '로그', icon = 'history')
        logs_item.add_widget(self._logs_screen)
        nav.add_widget(logs_item)
        return nav


    def _import_legacy_json(self, data_dir):
        import shutil
        import_dir = os.path.join(self.user_data_dir, 'import')
        if not os.path.isdir(import_dir):
            return None
        mapping = {
            'profile.json': None.path.join(data_dir, 'profile.json'),
            'quests.json': os.path.join(data_dir, 'quests.json'),
            'log.json': os.path.join(data_dir, 'log.json'),
            'achievements.json': os.path.join(data_dir, 'achievements.json') }
        imported = []
        for src_name, dst_path in mapping.items():
            src_path = os.path.join(import_dir, src_name)
            if os.path.exists(src_path):
                shutil.copy2(src_path, dst_path)
                imported.append(src_name)
                logging.info(f'''[Import] {src_name} → {dst_path}''')
                continue
                except Exception:
                    e = None
                    logging.error(f'''[Import] {src_name} 복사 실패: {e}''')
                    e = None
                    del e
                    continue
                    e = None
                    del e
            if imported:

                try:
                    shutil.rmtree(import_dir)
                except Exception:
                    pass

                self.store = GameStore(os.path.join(self.user_data_dir, 'data'))
                logging.info(f'''[Import] 이전 완료: {imported}''')
                return None


    def refresh_status(self):
        if hasattr(self, '_status_screen'):
            self._status_screen.refresh()
        if hasattr(self, '_logs_screen'):
            self._logs_screen.refresh()
            return None


if __name__ == '__main__':
    LifeRPGApp().run()
    return None
