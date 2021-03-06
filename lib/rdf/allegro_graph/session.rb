module RDF::AllegroGraph

  # A persistent AllegroGraph session.  This takes up more server resources
  # than a normal stateless repository connection, but it allows access to
  # advanced AllegroGraph features.
  #
  # Note that this class does not interoperate well with the Unix `fork`
  # command if you're using blank nodes.  See README.md for details.
  #
  # @see Repository#session
  class Session < AbstractRepository
    # Create a new session.  This parameter takes an
    # ::AllegroGraph::Repository object as an argument, so we've not going
    # to document it publically.
    #
    # @private
    def initialize(agraph_repo)
      super(::AllegroGraph::Session.create(agraph_repo))
      @last_unique_id = 0
    end

    # Explicitly close the current session and release all server resources.
    # This function does _not_ commit any outstanding transactions.
    #
    # @return [void]
    # @see #commit
    # @see #rollback
    def close
      @repo.request_http(:post, path('session/close'),
                         :expected_status_code => 204)
    end

    # Commit the current changes to the main repository.
    #
    # @return [void]
    # @see #rollback
    def commit
      @repo.commit
    end

    # Roll back the changes made since the last commit.
    #
    # @return [void]
    # @see #commit
    def rollback
      @repo.rollback
    end

    # Define an SNA generator.
    #
    # @param [Hash] options
    # @option options [RDF::Resource,Array<RDF::Resource>] :object_of
    #   Follow links defined by specified predicates.
    # @option options [RDF::Resource,Array<RDF::Resource>] :subject_of
    #   Follow links defined by specified predicates, but from the object
    #   to the subject.
    # @option options [RDF::Resource,Array<RDF::Resource>] :undirected
    #   Follow links defined by specified predicates in both directions.
    # @return [Query::PrologLiteral]
    #   A value which may be used in Prolog queries.
    #
    # @see Query#ego_group_member
    def generator(options)
      id = unique_id
      generator = SnaGenerator.new(self, options)
      @repo.request_json(:put, path("snaGenerators/#{id}"),
                         :parameters => generator.to_params,
                         :expected_status_code => 204)
      Query::PrologLiteral.new(id.to_sym)
    end

    protected

    def unique_id
      "id#{@last_unique_id += 1}"
    end
  end
end
