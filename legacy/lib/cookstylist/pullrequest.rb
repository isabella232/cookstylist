module Cookstylist
  class Pullrequest
    require "git"

    def initialize(repo, corrector)
      @repo = repo
      @corrector = corrector
      @gh_conn = Cookstylist::Github.instance.connection
      @number = nil
    end

    #
    # Open the Cookstyle PR against the repo
    #
    # @return [Boolean] was a PR opened?
    #
    def open
      commit_changes

      if Config[:whyrun]
        Log.info "  Would create pull request in repo: #{@repo.name} using branch #{@repo.cookstyle_branch_name} if not in whyrun mode"
      else
        pr = @gh_conn.create_pull_request(@repo.name, @repo.default_branch, @repo.cookstyle_branch_name, commit_title, commit_description)
        @number = pr[:number]
        return true
      end
      false
    end

    #
    # If there are older PRs then close them with a reference to the new PR
    #
    # @return [void]
    #
    def close_existing
      prs = @gh_conn.pull_requests(@repo.name)

      # find any open PRs by cookstyle bot
      prs.filter! { |x| x[:user][:login] == "cookstyle[bot]" && x[:state] == "open" }

      # We only want to close out the oldest PR if there's 2 or more
      return unless prs.count >= 2

      # sort by created date, drop the last one (current), and then close each old one why not
      # just assume there's only a new and old? Well what if someone reopens it or something
      # odd happens and the old one is never closed? Might as well assume 2+ to close
      old_prs = prs.sort_by { |pr| pr[:created_at] }
      old_prs.pop
      old_prs.each do |old_pr|
        @gh_conn.add_comment(@repo.name, old_pr[:number], "Closing this pull request as it has been superseded by https://github.com/#{@repo.name}/pull/#{@number}, which was created with Cookstyle #{Cookstyle::VERSION}.")
        @gh_conn.close_pull_request(@repo.name, old_pr[:number])
      end
    end

    def commit_changes
      r = Git.open(@repo.local_path)
      r.config("user.name", "Cookstyle Bot")
      r.config("user.email", "cookbooks@chef.io")

      r.commit_all("#{commit_title}\n#{commit_description}")

      if Config[:whyrun]
        Log.info "  Would push branch #{@repo.cookstyle_branch_name} to the remote if not in whyrun mode"
      else
        r.push("origin", @repo.cookstyle_branch_name)
      end
    end

    def commit_title
      "Cookstyle Bot Auto Corrections with Cookstyle #{Cookstyle::VERSION}"
    end

    def commit_description
      commit_msg = "This change is automatically generated by the Cookstyle Bot using the latest version of Cookstyle (#{Cookstyle::VERSION}). Adopting changes suggested by Cookstyle improves cookbook readability, avoids common coding mistakes, and eases upgrades to newer versions of the Chef Infra Client.\n\n"

      @corrector.results_by_cop.each do |cop_name, offenses|
        # build each line's description if it's correctable. We'll join them on their own line later
        file_descriptions = offenses.filter_map do |x|
          "  - **#{x["file_path"]}:#{x["location"]["start_line"]}**: #{x["message"]}" if x["corrected"]
        end

        commit_msg << "### #{cop_name}\n#{file_descriptions.join("\n")}\n\n" unless file_descriptions.empty?
      end

      commit_msg << "\nSigned-off-by: Cookstyle <cookbooks@chef.io>"

      Log.debug("Commit message:\n #{commit_msg}")
      commit_msg
    end
  end
end