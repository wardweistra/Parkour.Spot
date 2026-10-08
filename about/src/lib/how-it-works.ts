import {SITE_NAME} from "./brand";
import {
  ACTIVITY_FLOOR,
  activityFacts,
  countNoun,
  statsSentence,
  upcomingEventsPhrase,
} from "./citation";
import type {ScreenshotId} from "./screenshots";
import type {AboutStats} from "./types";
import {OPEN_SOURCE_URL, appHomeUrl, appPath} from "./urls";

/**
 * Shared copy for /how-it-works, its FAQPage schema, and the llms.txt task index.
 * Answer text is plain segments plus links so those three surfaces cannot drift.
 */

export interface AnswerLink {
  href: string;
  label: string;
}

export type AnswerPart = string | AnswerLink;

export interface HowItWorksQuestion {
  id: string;
  question: string;
  paragraphs: AnswerPart[][];
}

export interface HowItWorksGroup {
  id: string;
  title: string;
  questions: HowItWorksQuestion[];
  screenshot?: ScreenshotId;
}

export function isAnswerLink(part: AnswerPart): part is AnswerLink {
  return typeof part !== "string";
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/** One paragraph of HTML, with no gap between a link and the text beside it. */
export function paragraphHtml(paragraph: AnswerPart[]): string {
  return paragraph
    .map((part) =>
      isAnswerLink(part)
        ? `<a href="${escapeHtml(part.href)}">${escapeHtml(part.label)}</a>`
        : escapeHtml(part),
    )
    .join("");
}

export function answerPlainText(question: HowItWorksQuestion): string {
  return question.paragraphs
    .map((paragraph) =>
      paragraph
        .map((part) => (isAnswerLink(part) ? part.label : part))
        .join(""),
    )
    .join("\n\n");
}

const HOW_IT_WORKS_INTRO =
  `${SITE_NAME} is a free community map for finding parkour spots and events, adding and rating spots, keeping lists, and planning training with other people. You can explore the map without an account.`;

export function howItWorksLede(stats: AboutStats): string {
  const live = statsSentence(stats);
  return live ? `${HOW_IT_WORKS_INTRO} ${live}` : HOW_IT_WORKS_INTRO;
}

function positive(n: number | undefined): n is number {
  return typeof n === "number" && Number.isFinite(n) && n > 0;
}

function libraryParagraph(stats: AboutStats): AnswerPart[][] {
  if (!positive(stats.spotCount)) return [];
  const countries = positive(stats.countryCount)
    ? ` in ${countNoun(stats.countryCount, "country", "countries")}`
    : "";
  return [[`The map has ${countNoun(stats.spotCount, "public spot")}${countries}.`]];
}

function eventsParagraph(stats: AboutStats): AnswerPart[][] {
  const phrase = upcomingEventsPhrase(stats);
  return phrase ? [[`Right now there are ${phrase} on the map.`]] : [];
}

function sourcesParagraph(stats: AboutStats): AnswerPart[][] {
  if (!positive(stats.spotSourceCount)) return [];
  return [[
    `Alongside the spots added in the app, ${countNoun(stats.spotSourceCount, "community spot list")} feed the map so far, and new spots and lists are added every day.`,
  ]];
}

function curationParagraph(stats: AboutStats): AnswerPart[][] {
  const parts: string[] = [];
  if (positive(stats.improvementSuggestionCount)) {
    parts.push(`${countNoun(stats.improvementSuggestionCount, "suggestion and report", "suggestions and reports")} from the community`);
  }
  if (positive(stats.deduplicatedCount)) {
    parts.push(`${countNoun(stats.deduplicatedCount, "duplicate spot")} merged`);
  }
  if (parts.length === 0) return [];
  return [[`So far that adds up to ${parts.join(" and ")}.`]];
}

function activityQuestion(stats: AboutStats): HowItWorksQuestion[] {
  const recent = activityFacts(stats);
  const mau = positive(stats.monthlyActiveUsers) &&
    stats.monthlyActiveUsers >= ACTIVITY_FLOOR
    ? stats.monthlyActiveUsers
    : undefined;
  if (recent.length === 0 && mau == null) return [];
  const days = stats.activityWindowDays ?? 30;
  const paragraphs: AnswerPart[][] = [];
  if (mau != null) {
    paragraphs.push([
      `${countNoun(mau, "logged-in person", "logged-in people")} used ${SITE_NAME} in the last ${days} days. Many more explore without an account, since finding spots and events doesn't need one.`,
    ]);
  }
  if (recent.length > 0) {
    const list = recent.map((fact) => `${fact.value} ${fact.label}`);
    const joined = list.length === 1
      ? list[0]
      : `${list.slice(0, -1).join(", ")}, and ${list[list.length - 1]}`;
    paragraphs.push([`In the same ${days} days the community logged ${joined}.`]);
  }
  paragraphs.push([
    "These figures are recounted every night, so they always reflect the current map.",
  ]);
  return [{
    id: "how-active",
    question: `How active is the ${SITE_NAME} community?`,
    paragraphs,
  }];
}

const CONTACT_EMAIL = "parkour.spot@wardweistra.nl";

const explore = appPath("/explore");
const addSpot = appPath("/spots/add");
const addEvent = appPath("/events/add");
const mySpots = appPath("/profile/lists");

export function howItWorksGroups(stats: AboutStats): HowItWorksGroup[] {
  return [
  {
    id: "open-map",
    title: "Open map",
    questions: [
      {
        id: "need-account",
        question: `Do I need an account to use ${SITE_NAME}?`,
        paragraphs: [
          [
            "You can browse spots, photos, and ratings on ",
            {href: appHomeUrl(), label: "the map"},
            " without an account.",
          ],
          [
            "An account is for contributing: adding a spot or event, rating, keeping lists, checking in, and planning a session.",
          ],
        ],
      },
      {
        id: "free",
        question: `Is ${SITE_NAME} free?`,
        paragraphs: [
          [
            `Yes, everything on ${SITE_NAME} is free: browsing the map, adding spots and events, rating, keeping lists, checking in, and planning sessions.`,
          ],
          [
            "Creating an account is free too, and you only need one when you want to contribute.",
          ],
        ],
      },
    ],
  },
  {
    id: "find",
    title: "Find",
    screenshot: "eventsMobile",
    questions: [
      {
        id: "find-spots-near-me",
        question: "How do I find parkour spots near me?",
        paragraphs: [
          [
            "Open the ",
            {href: explore, label: "Explore"},
            " tab and search for a place or spot name, or tap Center on my location.",
          ],
          [
            "Each spot can include photos and a community rating, so you can see the place before you train there.",
          ],
          ...libraryParagraph(stats),
          [
            {href: "/", label: "Country and city pages"},
            " on this site list places that already have public spots.",
          ],
        ],
      },
      {
        id: "best-spots-near-me",
        question: "How do I find the best parkour spots near me?",
        paragraphs: [
          [
            "Judge a spot by its community rating: the average, how many people rated it, and the photos.",
          ],
          [
            "City pages list the highest-rated spots in that city, and the map has every public spot.",
          ],
        ],
      },
      {
        id: "find-events-near-me",
        question: "How do I find parkour events near me?",
        paragraphs: [
          [
            "Upcoming public jams and sessions show up on the map in the ",
            {href: explore, label: "Explore"},
            " tab, with the time and place.",
          ],
          ...eventsParagraph(stats),
          [
            "You can also browse them on the ",
            {href: "/events", label: "events page"},
            ", or on the country and city pages of this site.",
          ],
        ],
      },
    ],
  },
  {
    id: "add",
    title: "Add",
    questions: [
      {
        id: "add-spot",
        question: "How do I add a new parkour spot?",
        paragraphs: [
          [
            "Sign in, open the ",
            {href: addSpot, label: "Add"},
            " tab, and choose Add new spot.",
          ],
          [
            "Give it a name, a description, a location, and at least one photo. You can also mark what it is good for, its features, access, and facilities.",
          ],
          ["The spot joins the public map, so the next person can find it."],
        ],
      },
      {
        id: "add-event",
        question: "How do I add a new parkour event?",
        paragraphs: [
          [
            "Sign in, open the ",
            {href: addEvent, label: "Add"},
            " tab, and choose Add new event.",
          ],
          [
            "Set a title and a schedule, then choose one location: a point on the map, one or more spots, or one or more spot lists.",
          ],
          [
            "A moderator checks it, then it appears on the map and on the ",
            {href: "/events", label: "events page"},
            ".",
          ],
        ],
      },
      {
        id: "add-many-spots",
        question:
          "I have a list of parkour spots I want to add. How do I add them?",
        paragraphs: [
          [
            "If your spots are in a computer-readable format, such as Google My Maps, OpenStreetMap, or something similar, get in touch at ",
            {href: `mailto:${CONTACT_EMAIL}`, label: CONTACT_EMAIL},
            " and we can work out adding them in bulk.",
          ],
          [
            "For a few spots, ",
            {href: addSpot, label: "add each one"},
            " with a name, a description, a location, and a photo.",
          ],
        ],
      },
    ],
  },
  {
    id: "lists",
    title: "Lists",
    questions: [
      {
        id: "want-to-visit",
        question: "How do I keep a list of parkour spots I want to visit?",
        paragraphs: [
          [
            "Sign in, open a spot, and choose Want to visit.",
          ],
          [
            "You'll find them under ",
            {href: mySpots, label: "My spots"},
            " on the Account tab, ready for your next training trip.",
          ],
        ],
      },
      {
        id: "been-to",
        question: "How do I keep a list of parkour spots I have been to?",
        paragraphs: [
          ["Sign in, open a spot, and choose Been here."],
          [
            "They're collected under ",
            {href: mySpots, label: "My spots"},
            " on the Account tab, so you can look back on everywhere you have trained.",
          ],
        ],
      },
      {
        id: "create-spot-list",
        question: "How do I create a parkour spot list?",
        paragraphs: [
          [
            "Sign in, go to the Account tab, open ",
            {href: mySpots, label: "My spots"},
            ", and create a new list. You can also choose Add to a list on any spot.",
          ],
          [
            "Give it a name. You can add a description, a link for more information, sections, and a note on each spot.",
          ],
          [
            "The list can be public on your profile, visible only to people with the link, or private to you.",
          ],
        ],
      },
      {
        id: "event-spot-list",
        question: "How do I create a spot list for my parkour event?",
        paragraphs: [
          [
            "Create a spot list, add the spots for the session, and use sections or notes if the order matters.",
          ],
          [
            "When you ",
            {href: addEvent, label: "add the event"},
            ", choose Spot lists as the location and pick that list.",
          ],
          [
            "You can share the list before the event is public, or keep it private until you are ready.",
          ],
        ],
      },
      {
        id: "share-spot-list",
        question: "How do I share a parkour spot list?",
        paragraphs: [
          [
            "A public list appears on your profile, so anyone can open it.",
          ],
          [
            "An unlisted list is visible only with its link, and a private list is only for you.",
          ],
          [
            "When you open someone else's list, save it to keep it under ",
            {href: mySpots, label: "My spots"},
            ".",
          ],
        ],
      },
    ],
  },
  {
    id: "community",
    title: "Community",
    screenshot: "spotCommunityMobile",
    questions: [
      {
        id: "rate-spot",
        question: "How do I rate a parkour spot?",
        paragraphs: [
          ["Sign in and rate the spot from its page."],
          [
            "Each person has one rating. The spot shows the average and how many people rated it, so others can judge the place before they train there.",
          ],
        ],
      },
      {
        id: "plan-training",
        question: "How do I share a plan to go training?",
        paragraphs: [
          ["Open a spot and choose Plan a session."],
          [
            "Set the time you will be there, and add a short comment if you want.",
          ],
          [
            "A public plan is visible to people looking at that spot. Mark it private if it is only for you.",
          ],
        ],
      },
      {
        id: "check-in",
        question: "How do I let people know I am training at a spot now?",
        paragraphs: [
          ["Open a spot and check in, then set when you will leave."],
          [
            "Until that time, other people can see that you are here now, unless you keep the check-in private.",
          ],
          [
            "If you already planned a session, you can check in from that plan when you arrive.",
          ],
        ],
      },
      {
        id: "meet-community",
        question: `How do I meet the parkour community on ${SITE_NAME}?`,
        paragraphs: [
          [
            "Join a jam or session from the events page, see who is training at a spot right now or planning to, and browse the profiles and spot lists other people share.",
          ],
          [
            "Every rating, photo, and new spot you add helps the next person find a good place to train.",
          ],
        ],
      },
      ...activityQuestion(stats),
    ],
  },
  {
    id: "about-the-map",
    title: "About the map",
    questions: [
      {
        id: "where-spots-come-from",
        question: `Where do the spots on ${SITE_NAME} come from?`,
        paragraphs: [
          [
            "From two places: people who train there add spots directly, and local communities share the spot lists they have kept for years, such as the Apex Speed Run map and national lists from Czechia and Sweden. The URBN Jumpers team donated their spot data too.",
          ],
          ...sourcesParagraph(stats),
          [
            "Keep a list of spots yourself? ",
            {href: "#add-many-spots", label: "Here is how to add it"},
            ".",
          ],
        ],
      },
      {
        id: "spot-quality",
        question: "How is spot information kept accurate?",
        paragraphs: [
          [
            "Everyone gets one rating per spot, and the best-rated spots come first in every country and city.",
          ],
          [
            "Anyone can suggest a better name, photo, or location, or flag a spot that is closed, unsafe, or not a spot at all, even without an account.",
          ],
          [
            "New photos are checked automatically for harmful content, moderators review new contributions and reports, and duplicate spots from different lists are merged into one.",
          ],
          ...curationParagraph(stats),
        ],
      },
      {
        id: "install-app",
        question: `Can I install ${SITE_NAME} as an app?`,
        paragraphs: [
          [
            "Yes. Open ",
            {href: appHomeUrl(), label: "parkour.spot"},
            " in your browser and choose Install app or Add to home screen from the browser menu. On iPhone, tap Share and then Add to Home Screen.",
          ],
          [
            "It then opens from your home screen like any other app, on Android, iPhone, and computers.",
          ],
        ],
      },
      {
        id: "open-source",
        question: `Is ${SITE_NAME} open source?`,
        paragraphs: [
          [
            "Yes. ",
            {href: OPEN_SOURCE_URL, label: "The code is open source"},
            ", and the spot data stays freely available.",
          ],
          [
            "Parkour spot apps have come and gone, and too often their maps disappeared with them. The aim is that the community's spot knowledge outlives any single app.",
          ],
        ],
      },
    ],
  },
  ];
}

export function howItWorksQuestions(stats: AboutStats): HowItWorksQuestion[] {
  return howItWorksGroups(stats).flatMap((group) => group.questions);
}
