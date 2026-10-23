.pragma library

// Pure date math for the date & time panel. No Qt, no QML, no locale and no
// naming: the popup owns every label and format, so the grid logic here stays
// a plain function of its arguments.
//
// Months are 0-based everywhere, matching JS Date, so a caller never converts
// between two month conventions.

var MS_PER_DAY = 86400000

function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

// Stable "yyyy-MM-dd" identity for a cell, so a day can be compared against
// today in bindings without dragging Date objects around.
function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate())
}

function dayOfYear(year, month, day) {
  return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / MS_PER_DAY) + 1
}

function daysInYear(year) {
  return dayOfYear(year, 11, 31)
}

// Share of the year behind you: January 1 reads 0% and December 31 reads
// 100%, so the bar resets itself when the year rolls over.
function yearProgress(year, month, day) {
  var total = daysInYear(year)
  if (total <= 0)
    return 0
  return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total))
}

function yearProgressPercent(year, month, day) {
  return Math.round(yearProgress(year, month, day) * 100)
}

// ISO-8601 week number: the week owning the Thursday of that date's week.
function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7)
}

// Weekday indices follow JS Date.getDay(), so 0 is Sunday and 1 is Monday.
function weekdayOrder(weekStart) {
  var start = ((Number(weekStart) % 7) + 7) % 7
  var out = []
  for (var i = 0; i < 7; i++)
    out.push((start + i) % 7)
  return out
}

// Always six rows of seven days: a fixed grid keeps the panel the same height
// in every month, so stepping through the year never makes it jump.
//
// Walked in UTC, where a day is always 24 hours long. A local-midnight cursor
// has to be resolved by the engine in zones that start DST at 00:00, and that
// resolution lands on the previous or the next day depending on the engine. A
// grid of civil dates never needed a wall clock in the first place.
function monthGrid(year, month, weekStart, todayKey) {
  var start = ((Number(weekStart) % 7) + 7) % 7
  var leading = (new Date(Date.UTC(year, month, 1)).getUTCDay() - start + 7) % 7
  var cursor = new Date(Date.UTC(year, month, 1 - leading))
  var today = String(todayKey || "")
  var weeks = []

  for (var w = 0; w < 6; w++) {
    var days = []
    var thursday = null

    for (var d = 0; d < 7; d++) {
      var cellYear = cursor.getUTCFullYear()
      var cellMonth = cursor.getUTCMonth()
      var cellDay = cursor.getUTCDate()
      var weekday = cursor.getUTCDay()
      var key = dateKey(cellYear, cellMonth, cellDay)

      if (weekday === 4)
        thursday = { year: cellYear, month: cellMonth, day: cellDay }

      days.push({
        key: key,
        year: cellYear,
        month: cellMonth,
        day: cellDay,
        weekday: weekday,
        inMonth: cellMonth === month && cellYear === year,
        weekend: weekday === 0 || weekday === 6,
        today: key === today
      })

      cursor.setUTCDate(cursor.getUTCDate() + 1)
    }

    // Number every row by the ISO week owning its Thursday: stable for any
    // week start, and the definition itself for Monday-start weeks.
    var anchor = thursday || days[0]
    weeks.push({
      week: isoWeek(anchor.year, anchor.month, anchor.day),
      days: days
    })
  }

  return weeks
}

// Month stepping, UTC for the same reason as the grid: a first of the month
// with no local midnight would otherwise land in the wrong month.
function stepMonth(year, month, delta) {
  var target = new Date(Date.UTC(year, Number(month) + Number(delta), 1))
  return { year: target.getUTCFullYear(), month: target.getUTCMonth() }
}
