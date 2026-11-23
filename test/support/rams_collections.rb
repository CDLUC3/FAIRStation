module RamsCollections
  def rams_rows
    user = { "id" => 27, "type" => "users", "full_name" => "Researcher", "orcid" => "0000-0002-1825-0097" }
    { "reserves" => [ { "id" => 27, "name" => "Quail Ridge Reserve", "short_name" => "Quail", "description" => "", "doi" => "doi:10.21973/N30T0K", "latitude" => 38.48, "longitude" => 122.149444 } ],
      "projects" => (27..34).map { |id| rams_project(id, user) },
      "team_memberships" => [ rams_membership(user) ],
      "visits" => (27..34).map { |id| { "id" => id, "reserve" => { "id" => 27 }, "project" => { "id" => id }, "status" => "approved" } },
      "fundings" => [ { "id" => 1, "reserve" => { "id" => 27 }, "project" => { "id" => 27 }, "grant_number" => "123" } ],
      "institutions" => [ { "id" => 2, "name" => "University", "ror" => { "ror_id" => "https://ror.org/example" } } ] }
  end

  def rams_collections(rows)
    rows.transform_values { |data| { "data" => data, "total_count" => data.size } }
  end

  private

  def rams_project(id, user)
    %w[title abstract project_type status start_date end_date discipline discipline_other keywords taxonomic_keywords thesis_title course_title course_number submitted_at].index_with { nil }.merge(
      "id" => id, "title" => "Project #{id}", "abstract" => "Research context", "project_type" => "research",
      "status" => id < 30 ? "open" : "closed", "reserve" => { "id" => 27, "name" => "Quail Ridge Reserve" },
      "owner" => user, "applicant" => nil, "created_at" => "2020-01-01T00:00:00Z", "future_field" => "visible loss"
    )
  end

  def rams_membership(user)
    { "id" => 27, "project" => { "id" => 27 }, "user" => user,
      "user_role" => "graduate_student", "active" => false, "is_principal_investigator" => true,
      "institution" => { "id" => 2, "name" => "University" } }
  end
end
