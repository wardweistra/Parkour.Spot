import {SITE_NAME} from "./brand";
import {appHomeUrl, appPath} from "./urls";

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

export const HOW_IT_WORKS_LEDE =
  `${SITE_NAME} is a free community map for finding parkour spots and events, adding and rating spots, keeping lists, and planning training with other people. You can explore the map without an account.`;

const CONTACT_EMAIL = "parkour.spot@wardweistra.nl";

const explore = appPath("/explore");
const addSpot = appPath("/spots/add");
const addEvent = appPath("/events/add");
const mySpots = appPath("/profile/lists");

export const HOW_IT_WORKS_GROUPS: HowItWorksGroup[] = [
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
    ],
  },
];

export function howItWorksQuestions(): HowItWorksQuestion[] {
  return HOW_IT_WORKS_GROUPS.flatMap((group) => group.questions);
}
