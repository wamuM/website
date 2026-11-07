async function loadGitShowcase() {
  const USERNAME = 'wamuM';
  const showcase = document.getElementById('git-showcase');

  if (!showcase) return;

  try {
    const url = `https://api.github.com/search/commits?q=author:${USERNAME}&sort=author-date&order=desc&per_page=1`;
    const response = await fetch(url);
    
    // Check for HTTP errors (e.g. 403 Rate Limit or 404 Not Found)
    if (!response.ok) {
      throw new Error(`GitHub API HTTP ${response.status}`);
    }

    const commits = (await response.json()).items;
    console.log(commits)
    const latestCommit = commits[0];

    if (latestCommit) {
      showcase.innerHTML = `
          <p>
          <span>Reposiory:</span><a class="repo" href="${latestCommit.repository.html_url}" target="_blank">${latestCommit.repository.name}</a>
          </p>
          <p>
          <span>Commit:</span><a class="commit" href="${latestCommit.html_url}" target="_blank">
            <span class="sha">[${latestCommit.sha.substring(0,7)}]</span> <span class="message">${latestCommit.commit.message}</span>
          </a>
          </p>
      `;
    } else {
      showcase.innerHTML = `<p>No recent public commits found.</p>`;
    }
  } catch (err) {
    console.error('Git showcase error:', err);
    showcase.innerHTML = `<p class="commit-error">Failed to load commit activity.</p>`;
  }
}
loadGitShowcase();
