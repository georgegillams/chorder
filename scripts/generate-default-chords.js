const words2 = [
  "as",
  "to",
  "be",
  "in",
  "by",
  "is",
  "it",
  "at",
  "of",
  "or",
  "on",
  "an",
  "us",
  "if",
  "my",
  "do",
  "he",
  "up",
  "so",
  "am",
  "me",
  "go",
  "oh",
  "ad",
  "ok",
  "hi",
  "eg",
  "ie",
  "mr",
  "vs",
  "eu",
  "dj",
];

const words3 = [
  "and",
  "are",
  "for",
  "you",
  "not",
  "the",
  "all",
  "new",
  "was",
  "can",
  "has",
  "but",
  "our",
  "one",
  "may",
  "out",
  "use",
  "any",
  "see",
  "his",
  "who",
  "now",
  "get",
  "how",
  "its",
  "top",
  "had",
  "day",
  "two",
  "buy",
  "her",
  "add",
  "jan",
  "she",
  "set",
  "map",
  "way",
  "off",
  "did",
  "car",
  "own",
  "end",
  "him",
  "per",
  "big",
  "law",
  "art",
  "usa",
  "old",
  "non",
  "why",
  "low",
  "man",
  "job",
  "too",
  "men",
  "box",
  "air",
  "yes",
  "hot",
  "say",
  "dec",
  "san",
  "tax",
  "got",
  "let",
  "act",
  "red",
  "key",
  "few",
  "age",
  "oct",
  "pay",
  "war",
  "nov",
  "fax",
  "yet",
  "sun",
  "run",
  "net",
  "put",
  "try",
  "god",
  "log",
  "faq",
  "fun",
  "sep",
  "lot",
  "ask",
  "due",
  "mar",
  "pro",
  "aug",
  "ago",
  "apr",
  "via",
  "bad",
  "far",
  "jun",
  "oil",
];

const word2Exclude = ["no"];

const word3Exclude = [
  "ago",
  "art",
  "buy",
  "car",
  "fax",
  "faq",
  "had",
  "log",
  "lot",
  "net",
  "out",
  "set",
  "sep",
  "was",
  "war",
  "who",
  "yet",
];

const processed2 = words2
  .filter((w) => !word2Exclude.includes(w))
  .map((w) => {
    const wordSorted = w.split("").sort().join("");
    console.log(wordSorted);
    return {
      // input is the word sorted alphabetically
      sorted: wordSorted,
      input: w,
      output: w,
    };
  })
  .sort((a, b) => a.input.localeCompare(b.input));

console.log(JSON.stringify(processed2, null, 2));

const processed3 = words3
  .filter((w) => !word3Exclude.includes(w))
  .map((w) => {
    const wordSorted = w.split("").sort().join("");
    const uniqueLetterCount = [...new Set(wordSorted)].length;
    const wordWithUniqueLettersOnly = [...new Set(w)].join("");
    const wordWithUniqueLettersOnlySorted = wordWithUniqueLettersOnly
      .split("")
      .sort()
      .join("");
    if (
      uniqueLetterCount === 2 &&
      !processed2.some((p) => p.sorted === wordWithUniqueLettersOnlySorted)
    ) {
      return {
        input: wordWithUniqueLettersOnly,
        output: w,
      };
    }

    const first2Letters = w.slice(0, 2);
    first2Sorted = first2Letters.split("").sort().join("");

    if (!processed2.some((p) => p.sorted === first2Sorted)) {
      return {
        input: first2Letters,
        output: w,
      };
    }

    return null;
  })
  .filter((p) => !!p)
  .sort((a, b) => a.input.localeCompare(b.input));

console.log(JSON.stringify(processed3, null, 2));
