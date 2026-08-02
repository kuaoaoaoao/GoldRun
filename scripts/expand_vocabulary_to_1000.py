#!/usr/bin/env python3
"""生成 EnglishVocabularyThousandExpansion.json，把每个学段词量补到 1000。

策略：
1. 先写入一批全局全新的学术词（雅思/托福/六级方向）。
2. 不足部分从难度相邻学段借调已有词条（按学段去重，借调合法且质量有保障）。
"""
import json
import re
import collections
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "CoolRun"
TARGET = 1000
STAGES = ["daily", "primary_school", "middle_school", "high_school",
          "cet4", "cet6", "ielts", "toefl"]

# 各学段借调来源（按优先级，只借难度相邻学段的词）
BORROW_SOURCES = {
    "daily": ["primary_school", "middle_school", "high_school", "cet4"],
    "primary_school": ["daily", "middle_school"],
    "middle_school": ["primary_school", "high_school", "daily"],
    "high_school": ["cet4", "middle_school", "cet6"],
    "cet4": ["high_school", "cet6", "middle_school"],
    "cet6": ["cet4", "ielts", "toefl", "high_school"],
    "ielts": ["cet6", "toefl", "cet4", "high_school"],
    "toefl": ["cet6", "ielts", "cet4", "high_school"],
}

EXISTING_FILES = [
    "EnglishVocabularyStarterSupplement", "EnglishVocabularySupplement",
    "EnglishVocabularyBulkSupplement", "EnglishVocabularyLevelSupplement",
    "EnglishVocabularyDailyExpansion", "EnglishVocabularyCet6Expansion",
    "EnglishVocabularyIeltsExpansion", "EnglishVocabularyToeflExpansion",
    "EnglishVocabularyDailyMegaExpansion", "EnglishVocabularySchoolMegaExpansion",
    "EnglishVocabularyAdvancedMegaExpansion", "EnglishVocabularyExamMegaExpansion",
]

# 全新学术词：word, translation, part, example, exampleTranslation, 目标学段列表
NEW_WORDS = [
    ("meticulous", "一丝不苟的", "adj.", "She keeps meticulous records of every experiment.", "她对每次实验都做一丝不苟的记录。", ["ielts", "toefl"]),
    ("benevolent", "仁慈的", "adj.", "The benevolent donor gave millions to charity.", "这位仁慈的捐赠者向慈善机构捐了数百万。", ["ielts", "toefl"]),
    ("coherent", "连贯的", "adj.", "A coherent essay needs clear logic.", "一篇连贯的文章需要清晰的逻辑。", ["ielts", "toefl"]),
    ("pragmatic", "务实的", "adj.", "We need a pragmatic approach to this problem.", "我们需要用务实的方法解决这个问题。", ["ielts", "toefl"]),
    ("scrutiny", "仔细审查", "n.", "The report is under close scrutiny.", "这份报告正受到严密审查。", ["ielts", "toefl"]),
    ("empirical", "实证的", "adj.", "The theory lacks empirical evidence.", "这一理论缺乏实证依据。", ["ielts", "toefl"]),
    ("plausible", "貌似合理的", "adj.", "His explanation sounds plausible.", "他的解释听起来貌似合理。", ["ielts", "toefl"]),
    ("intricate", "错综复杂的", "adj.", "The watch has an intricate mechanism.", "这块手表有着错综复杂的机械结构。", ["ielts", "toefl"]),
    ("resilient", "有韧性的", "adj.", "Children are often remarkably resilient.", "孩子们往往有惊人的韧性。", ["ielts", "toefl"]),
    ("ambiguous", "模棱两可的", "adj.", "The contract terms are ambiguous.", "合同条款模棱两可。", ["ielts", "toefl"]),
    ("credible", "可信的", "adj.", "The witness gave a credible account.", "证人提供了可信的陈述。", ["ielts", "toefl"]),
    ("deteriorate", "恶化", "v.", "His health began to deteriorate rapidly.", "他的健康状况开始迅速恶化。", ["ielts", "toefl"]),
    ("proliferate", "激增", "v.", "Online courses have proliferated in recent years.", "近年来网络课程激增。", ["ielts", "toefl"]),
    ("mitigate", "缓解", "v.", "Trees help mitigate air pollution.", "树木有助于缓解空气污染。", ["ielts", "toefl"]),
    ("articulate", "清晰表达", "v.", "She can articulate complex ideas simply.", "她能把复杂的想法表达得简单清晰。", ["ielts", "toefl"]),
    ("consolidate", "巩固", "v.", "Review helps consolidate new knowledge.", "复习有助于巩固新知识。", ["ielts", "toefl"]),
    ("exemplify", "举例说明", "v.", "This case exemplifies the wider problem.", "这个案例充分说明了更普遍的问题。", ["ielts", "toefl"]),
    ("undermine", "削弱", "v.", "Rumors can undermine public trust.", "谣言会削弱公众信任。", ["ielts", "toefl"]),
    ("advocate", "提倡", "v.", "Experts advocate regular exercise.", "专家提倡定期锻炼。", ["ielts", "toefl"]),
    ("attribute", "归因于", "v.", "She attributes her success to hard work.", "她把成功归因于努力工作。", ["ielts", "toefl"]),
    ("paradigm", "范式", "n.", "The discovery created a new scientific paradigm.", "这一发现开创了新的科学范式。", ["ielts", "toefl"]),
    ("consensus", "共识", "n.", "The committee reached a consensus.", "委员会达成了共识。", ["ielts", "toefl"]),
    ("dilemma", "两难困境", "n.", "She faced a moral dilemma.", "她面临道德上的两难困境。", ["ielts", "toefl"]),
    ("incentive", "激励", "n.", "Bonuses are an incentive to work harder.", "奖金是更努力工作的激励。", ["ielts", "toefl"]),
    ("legislation", "立法", "n.", "New legislation protects consumer rights.", "新立法保护消费者权益。", ["ielts", "toefl"]),
    ("infrastructure", "基础设施", "n.", "The city invested in transport infrastructure.", "该市投资了交通基础设施。", ["ielts", "toefl"]),
    ("hierarchy", "等级制度", "n.", "The company has a strict hierarchy.", "这家公司有严格的等级制度。", ["ielts", "toefl"]),
    ("magnitude", "重要程度；量级", "n.", "They underestimated the magnitude of the task.", "他们低估了这项任务的艰巨程度。", ["ielts", "toefl"]),
    ("constraint", "限制", "n.", "Budget constraints delayed the project.", "预算限制推迟了项目。", ["ielts", "toefl"]),
    ("criterion", "标准", "n.", "Quality is the main criterion for selection.", "质量是选拔的主要标准。", ["ielts"]),
    ("equilibrium", "平衡", "n.", "The market will return to equilibrium.", "市场将恢复平衡。", ["ielts", "toefl"]),
    ("phenomenon", "现象", "n.", "Migration is a global phenomenon.", "移民是一种全球现象。", ["ielts"]),
    ("hypothesis", "假说", "n.", "The data supports our hypothesis.", "数据支持我们的假说。", ["toefl"]),
    ("catalyst", "催化剂；促进因素", "n.", "The event was a catalyst for change.", "这一事件是变革的催化剂。", ["ielts", "toefl"]),
    ("trajectory", "轨迹", "n.", "The company is on a growth trajectory.", "公司正处于增长轨迹上。", ["ielts", "toefl"]),
    ("discourse", "论述；话语", "n.", "Public discourse shapes policy.", "公共论述影响政策。", ["ielts", "toefl"]),
    ("premise", "前提", "n.", "The argument rests on a false premise.", "这个论证建立在错误的前提之上。", ["ielts", "toefl"]),
    ("anomaly", "异常", "n.", "The result was a statistical anomaly.", "这个结果是统计上的异常。", ["ielts", "toefl"]),
    ("repercussion", "后果；影响", "n.", "The decision had serious repercussions.", "这个决定产生了严重的后果。", ["ielts", "toefl"]),
    ("connotation", "内涵；隐含意义", "n.", "The word has a negative connotation.", "这个词带有负面的隐含意义。", ["ielts", "toefl"]),
    ("juxtapose", "并列对比", "v.", "The exhibit juxtaposes old and new art.", "展览将新旧艺术并列对比。", ["ielts", "toefl"]),
    ("extrapolate", "推断", "v.", "We can extrapolate trends from the data.", "我们可以从数据中推断趋势。", ["ielts", "toefl"]),
    ("substantiate", "证实", "v.", "The claim was never substantiated.", "这一说法从未得到证实。", ["ielts", "toefl"]),
    ("elucidate", "阐明", "v.", "The professor elucidated the theory.", "教授阐明了这一理论。", ["ielts", "toefl"]),
    ("permeate", "渗透", "v.", "Technology permeates modern life.", "科技渗透到现代生活中。", ["ielts", "toefl"]),
    ("culminate", "达到顶点", "v.", "Years of work culminated in success.", "多年的努力最终取得成功。", ["ielts", "toefl"]),
    ("juxtaposition", "并置", "n.", "The juxtaposition of colors is striking.", "色彩的并置效果惊人。", ["toefl"]),
    ("exacerbate", "加剧", "v.", "Stress can exacerbate illness.", "压力会加剧疾病。", ["ielts", "toefl"]),
    ("alleviate", "减轻", "v.", "Medicine can alleviate the pain.", "药物可以减轻疼痛。", ["ielts", "toefl"]),
    ("stipulate", "规定", "v.", "The contract stipulates a deadline.", "合同规定了截止日期。", ["ielts", "toefl"]),
    ("perpetuate", "使持续", "v.", "Stereotypes perpetuate inequality.", "刻板印象使不平等持续存在。", ["ielts", "toefl"]),
    ("obsolete", "过时的", "adj.", "The technology quickly became obsolete.", "这项技术很快就过时了。", ["ielts", "toefl"]),
    ("tangible", "有形的；切实的", "adj.", "The project produced tangible results.", "该项目产生了切实的成果。", ["ielts", "toefl"]),
    ("volatile", "不稳定的", "adj.", "Oil prices remain volatile.", "油价依然不稳定。", ["ielts", "toefl"]),
    ("feasible", "可行的", "adj.", "The plan is technically feasible.", "该计划在技术上是可行的。", ["ielts", "toefl"]),
    ("susceptible", "易受影响的", "adj.", "Children are susceptible to colds.", "儿童容易感冒。", ["ielts", "toefl"]),
    ("indispensable", "不可或缺的", "adj.", "Water is indispensable to life.", "水是生命不可或缺的。", ["ielts", "toefl"]),
    ("arbitrary", "武断的；任意的", "adj.", "The rule seems completely arbitrary.", "这条规则似乎完全是武断的。", ["ielts", "toefl"]),
    ("meticulously", "一丝不苟地", "adv.", "The garden is meticulously maintained.", "花园被打理得一丝不苟。", ["toefl"]),
    ("inevitably", "不可避免地", "adv.", "Change inevitably brings challenges.", "变革不可避免地带来挑战。", ["ielts", "toefl"]),
    ("predominantly", "主要地", "adv.", "The region is predominantly rural.", "该地区以农村为主。", ["ielts", "toefl"]),
    ("simultaneously", "同时地", "adv.", "The events happened simultaneously.", "这些事件同时发生。", ["ielts", "toefl"]),
    ("subsequently", "随后", "adv.", "He subsequently changed his mind.", "他随后改变了主意。", ["ielts", "toefl"]),
    ("empathy", "共情", "n.", "Good doctors show empathy for patients.", "好医生对病人有共情。", ["ielts", "toefl", "cet6"]),
    ("integrity", "正直；完整", "n.", "She is admired for her integrity.", "她因正直而受到敬佩。", ["ielts", "toefl", "cet6"]),
    ("autonomy", "自主权", "n.", "Students need some autonomy in learning.", "学生在学习中需要一定的自主权。", ["ielts", "toefl", "cet6"]),
    ("nuance", "细微差别", "n.", "Translation must capture every nuance.", "翻译必须捕捉每个细微差别。", ["ielts", "toefl"]),
    ("skepticism", "怀疑态度", "n.", "The claim was met with skepticism.", "这一说法遭到怀疑。", ["ielts", "toefl"]),
    ("altruism", "利他主义", "n.", "Altruism benefits society as a whole.", "利他主义使整个社会受益。", ["ielts", "toefl"]),
    ("cognition", "认知", "n.", "Sleep affects memory and cognition.", "睡眠影响记忆与认知。", ["ielts", "toefl"]),
    ("aesthetics", "美学", "n.", "The design balances function and aesthetics.", "这个设计兼顾功能与美学。", ["ielts", "toefl"]),
    ("demographics", "人口结构", "n.", "Changing demographics affect housing demand.", "人口结构变化影响住房需求。", ["ielts", "toefl"]),
    ("sustainability", "可持续性", "n.", "Sustainability is central to urban planning.", "可持续性是城市规划的核心。", ["ielts", "toefl"]),
    ("biodiversity", "生物多样性", "n.", "Rainforests are rich in biodiversity.", "雨林拥有丰富的生物多样性。", ["ielts", "toefl"]),
    ("urbanization", "城市化", "n.", "Rapid urbanization strains public services.", "快速城市化使公共服务承压。", ["ielts", "toefl"]),
    ("globalization", "全球化", "n.", "Globalization connects distant economies.", "全球化连接了遥远的经济体。", ["ielts", "toefl"]),
    ("commodity", "商品", "n.", "Coffee is a major global commodity.", "咖啡是重要的全球性商品。", ["ielts", "toefl", "cet6"]),
    ("subsidy", "补贴", "n.", "Farmers receive government subsidies.", "农民获得政府补贴。", ["ielts", "toefl", "cet6"]),
    ("tariff", "关税", "n.", "The tariff raised import prices.", "关税提高了进口价格。", ["ielts", "toefl", "cet6"]),
    ("monopoly", "垄断", "n.", "The company holds a near monopoly.", "这家公司几乎处于垄断地位。", ["ielts", "toefl", "cet6"]),
    ("inflation", "通货膨胀", "n.", "Inflation eroded their savings.", "通货膨胀使他们的积蓄缩水。", ["ielts", "toefl"]),
    ("recession", "经济衰退", "n.", "The economy slipped into recession.", "经济陷入了衰退。", ["ielts", "toefl"]),
    ("entrepreneur", "企业家", "n.", "The entrepreneur started three companies.", "这位企业家创办了三家公司。", ["ielts", "toefl"]),
    ("bureaucracy", "官僚体系", "n.", "Excessive bureaucracy slows innovation.", "过度的官僚体系拖慢创新。", ["ielts", "toefl"]),
    ("censorship", "审查制度", "n.", "The film faced censorship in some regions.", "这部电影在一些地区遭到审查。", ["ielts", "toefl"]),
    ("plagiarism", "抄袭", "n.", "Plagiarism is a serious academic offense.", "抄袭是严重的学术不端行为。", ["ielts", "toefl"]),
    ("curriculum", "课程体系", "n.", "The school updated its science curriculum.", "学校更新了科学课程体系。", ["ielts", "toefl"]),
    ("pedagogy", "教学法", "n.", "Modern pedagogy emphasizes active learning.", "现代教学法强调主动学习。", ["toefl"]),
    ("dissertation", "学位论文", "n.", "She is writing her doctoral dissertation.", "她正在撰写博士学位论文。", ["ielts", "toefl"]),
    ("seminar", "研讨会", "n.", "The seminar covered research methods.", "研讨会讲授了研究方法。", ["ielts", "toefl"]),
    ("sabbatical", "学术休假", "n.", "The professor took a year-long sabbatical.", "教授休了一年的学术假。", ["toefl"]),
    ("archaeology", "考古学", "n.", "Archaeology reveals ancient civilizations.", "考古学揭示古代文明。", ["ielts", "toefl"]),
    ("anthropology", "人类学", "n.", "Anthropology studies human cultures.", "人类学研究人类文化。", ["ielts", "toefl"]),
    ("linguistics", "语言学", "n.", "Linguistics examines how languages work.", "语言学研究语言的运作方式。", ["ielts", "toefl"]),
    ("meteorology", "气象学", "n.", "Meteorology helps predict storms.", "气象学有助于预测风暴。", ["toefl"]),
    ("geology", "地质学", "n.", "Geology explains how mountains form.", "地质学解释山脉如何形成。", ["ielts", "toefl"]),
    ("photosynthesis", "光合作用", "n.", "Photosynthesis converts sunlight into energy.", "光合作用把阳光转化为能量。", ["toefl"]),
    ("metabolism", "新陈代谢", "n.", "Exercise boosts your metabolism.", "运动能促进新陈代谢。", ["ielts", "toefl"]),
    ("immunity", "免疫力", "n.", "Vaccines build immunity against disease.", "疫苗建立对疾病的免疫力。", ["ielts", "toefl"]),
    ("epidemic", "流行病", "n.", "The epidemic spread across the region.", "流行病在该地区蔓延。", ["ielts", "toefl"]),
    ("sanitation", "环境卫生", "n.", "Clean water and sanitation save lives.", "清洁的水和卫生设施拯救生命。", ["ielts", "toefl"]),
    ("nutrition", "营养", "n.", "Good nutrition is vital for children.", "良好的营养对儿童至关重要。", ["ielts", "toefl"]),
    ("sediment", "沉积物", "n.", "The river deposits sediment at its mouth.", "河流在入海口沉积泥沙。", ["toefl"]),
    ("erosion", "侵蚀", "n.", "Coastal erosion threatens the village.", "海岸侵蚀威胁着这个村庄。", ["ielts", "toefl"]),
    ("glacier", "冰川", "n.", "The glacier is retreating every year.", "冰川每年都在退缩。", ["ielts", "toefl"]),
    ("drought", "干旱", "n.", "The drought ruined this year's harvest.", "干旱毁掉了今年的收成。", ["ielts", "toefl"]),
    ("irrigation", "灌溉", "n.", "Irrigation made the desert farmland fertile.", "灌溉使沙漠农田变得肥沃。", ["ielts", "toefl"]),
    ("pesticide", "杀虫剂", "n.", "Pesticides can harm beneficial insects.", "杀虫剂可能伤害益虫。", ["ielts", "toefl"]),
    ("emission", "排放", "n.", "The city aims to cut carbon emissions.", "该市计划削减碳排放。", ["ielts", "toefl"]),
    ("renewable", "可再生的", "adj.", "Solar power is a renewable resource.", "太阳能是可再生资源。", ["ielts", "toefl"]),
    ("habitat", "栖息地", "n.", "Deforestation destroys animal habitats.", "滥伐森林破坏动物栖息地。", ["ielts", "toefl"]),
    ("predator", "捕食者", "n.", "The hawk is a skilled predator.", "鹰是熟练的捕食者。", ["ielts", "toefl"]),
    ("ecosystem", "生态系统", "n.", "Wetlands form a delicate ecosystem.", "湿地构成脆弱的生态系统。", ["ielts", "toefl"]),
    ("extinction", "灭绝", "n.", "Many species face extinction.", "许多物种面临灭绝。", ["ielts", "toefl"]),
    ("conservation", "保护", "n.", "Wildlife conservation needs public support.", "野生动物保护需要公众支持。", ["ielts", "toefl"]),
]


def load_pools():
    """返回 stage -> {word_lower: entry} 的原始词条池，以及各学段现有词集合。"""
    pools = {s: {} for s in STAGES}
    for name in EXISTING_FILES:
        data = json.loads((ROOT / f"{name}.json").read_text(encoding="utf-8"))
        for group in data:
            for item in group["items"]:
                key = item["word"].strip().lower()
                if key and key not in pools[group["stage"]]:
                    pools[group["stage"]][key] = item

    # 内置 Swift 词条（仅用于查重，不作为借调来源，借调需要完整 JSON 词条）
    swift = (ROOT / "EnglishVocabulary.swift").read_text(encoding="utf-8")
    camel = {"daily": "daily", "primarySchool": "primary_school",
             "middleSchool": "middle_school", "highSchool": "high_school",
             "cet4": "cet4", "cet6": "cet6", "ielts": "ielts", "toefl": "toefl"}
    builtin = collections.defaultdict(set)
    pattern = r'word\(\.(\w+),\s*"[^"]*",\s*"([^"]+)"'
    for m in re.finditer(pattern, swift):
        builtin[camel[m.group(1)]].add(m.group(2).strip().lower())

    known = {s: set(pools[s]) | builtin[s] for s in STAGES}
    return pools, known


def main():
    pools, known = load_pools()
    global_words = set().union(*known.values())
    result = {s: [] for s in STAGES}

    # 1. 全新学术词（跳过全局已有的词）
    added_new = 0
    for word, trans, part, ex, ex_trans, stages in NEW_WORDS:
        key = word.strip().lower()
        if not key or not trans or key in global_words:
            continue
        entry = {"word": word, "translation": trans, "part": part,
                 "example": ex, "exampleTranslation": ex_trans}
        placed = False
        for stage in stages:
            if len(known[stage]) >= TARGET or key in known[stage]:
                continue
            result[stage].append(entry)
            known[stage].add(key)
            placed = True
        if placed:
            global_words.add(key)
            added_new += 1

    # 2. 借调相邻学段词条补足到 1000
    for stage in STAGES:
        need = TARGET - len(known[stage])
        if need <= 0:
            continue
        for source in BORROW_SOURCES[stage]:
            if need <= 0:
                break
            for key in sorted(pools[source]):
                if need <= 0:
                    break
                if key in known[stage]:
                    continue
                result[stage].append(pools[source][key])
                known[stage].add(key)
                need -= 1
        if need > 0:
            print(f"WARNING: {stage} 仍缺 {need} 词")

    output = [{"stage": s, "items": result[s]} for s in STAGES if result[s]]
    out_path = ROOT / "EnglishVocabularyThousandExpansion.json"
    out_path.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"全新词条: {added_new}")
    for s in STAGES:
        print(f"{s}: 新增 {len(result[s])}, 最终 {len(known[s])}")
    print(f"全局唯一词: {len(set().union(*known.values()))}")


if __name__ == "__main__":
    main()
