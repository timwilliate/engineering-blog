var GH_API_URI = "https://api.github.com"

var REPOS_PER_ROW = 100000;

var repos = [ ];

$(document).ready(function() {
  loadRepos(1);
  updateMembers();
});

function loadRepos(page) {
  $.getJSON(GH_API_URI + "/orgs/MonsantoCo/repos?per_page=100&page=" + page,
    function(result) {
      if (result && result.length > 0) {
        repos = repos.concat(result);
        loadRepos(page + 1);
      }
      else {
        addRepos(repos);
      }
    }).fail(function(xhr,textStatus,error) {
      $("#loading").addClass("networkError").text("An error occurred while communicating with GitHub.");
      if (xhr.responseJSON && xhr.responseJSON["message"]) {
        $("<div>").text("(" + xhr.responseJSON["message"] + ")").appendTo($("#loading"));
      }
      $("#fallback").removeClass("hidden");
      //getResponseHeader("X-RateLimit-Remaining"
      //getResponseHeader("X-RateLimit-Limit")
    });
}

function addRepos(repos) {
  var starWeight = 9; // repo watchers
  var forkWeight = 3; // forks of the repo
  var giltWeight = 1000000;  // if the gilt repo is actually a fork

  //repos = repos.filter(starFilter);

  // Sort weight priority: gilt repo, starred, watched, activity
  $.each(repos, function(i,repo) { // assign weights
    var weight =
      (repo.stargazers_count * starWeight) +
      (repo.forks_count * forkWeight) +
      (!repo.fork * giltWeight);
    repo["gilt_weight"] = weight;
  });
  console.log(repos);

  repos = repos.sort(function(a,b) {
    var aw = a["gilt_weight"];
    var bw = b["gilt_weight"];
    if (aw == bw) {
      return 0;
    } else if (aw < bw) {
      return 1;
    }
    else {
      return -1;
    }
  });

  $("#loading").addClass("hidden");

  $.each(repos, function(i,repo) {
    addRepo(i, repo);
  });

  // show repo stats
  var stats = $("#repo-stats").text("Providing ");
  $("<a>").attr("href", "https://github.com/MonsantoCo").text(repos.length + " public repositories").appendTo(stats);
  stats.removeClass("hidden");
}

//function starFilter(repo) {
 // return repo.stargazers_count <= 0;
//}

function addRepo(i, repo) {
  var row = $("#all-repos").children().last();
  if (! row || i % REPOS_PER_ROW == 0) {
    row = $("<div>").addClass("repo-row row");
    row.appendTo("#all-repos");
  }

  var c = $("<div>").addClass("col-lg-4 col-md-6 col-sm-6 col-xs-12");
  var r = $("<div>").addClass("repo").appendTo(c);
  var a = $("<a>").attr("href", repo.html_url).appendTo(r);

  $("<i>").addClass("icon-star repo-icon").appendTo(a);
  $("<span>").addClass("count").text(repo.watchers_count).appendTo(a);

  $("<i>").addClass("icon-code-fork repo-icon").appendTo(a);
  $("<span>").addClass("count").text(repo.forks_count).appendTo(a);

  if (repo.private) {
    $("<i>").addClass("icon-lock").appendTo(a);
  }

  var lang = repo.language;
  if (lang) {
    $("<span>").addClass("lang " + lang.toLowerCase()).text(lang).appendTo(a);
  }

  $("<h4>").addClass("name").text(repo.name).appendTo(a);
  $("<p>").addClass("description").text(repo.description).appendTo(a);

  c.appendTo(row);
}

function updateMembers() {
  $.getJSON(GH_API_URI + "/orgs/MonsantoCo/members?per_page=150", function(result) {
    if (result && result.length > 0) {
      var stats = $("#member-stats").text("We are ");
      $("<a>").attr("href", "https://github.com/MonsantoCo?tab=members").text(result.length + " members").appendTo(stats);
      stats.removeClass("hidden");

      // The "Providing N repos" message is designed to be displayed standalone
      // add style to match up the letter case
      $("#repo-stats").addClass("repo-stats-inline");
    }
  });
}
