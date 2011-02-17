module RDF::AllegroGraph

  # A query with AllegroGraph-specific extensions.
  #
  # Note that many of of the more exotic features of this class can only be
  # used when running Prolog queries against a Session object.  This
  # requires both elevated AllegroGraph privileges and dedicated back-end
  # session resources on the server, so plan accordingly.
  #
  # @see AbstractRepository#build_query
  class Query < RDF::Query
    autoload :PrologLiteral, 'rdf/allegro_graph/query/prolog_literal'
    autoload :Relation, 'rdf/allegro_graph/query/relation'

    # Create a new query.
    # @private
    def initialize(repository, &block)
      @repository = repository
      super(&block)
    end

    # Run this query against the associated repository.  This method exists
    # solely to make the following API pleasant to use:
    #
    #     repo.build_query do |q|
    #       q.pattern [:s, :p, :o]
    #     end.run do |solution|
    #       puts solution
    #     end
    #
    # Note that this function returns an Enumerator, not an array, because
    # RDF.rb is committed to streaming results gradually.  If you want to
    # treat the result as an array, call 'to_a' explicitly:
    #
    #     solutions = repo.build_query do |q|
    #       q.pattern [:s, :p, :o]
    #     end.run.to_a
    #
    # If you forget to do this, you will run a new query each time you
    # attempt to iterate over the solutions!
    #
    # @overload run
    #   @return [Enumerable::Enumerator<RDF::Query::Solution>]
    #
    # @overload run
    #   @yield solution
    #   @yieldparam [RDF::Query::Solution]
    #   @yieldreturn [void]
    #   @return [void]
    #
    # @see Repository#query
    # @note This function returns a single-use Enumerator!  If you want to
    #   to treat the results as an array, call `to_a` on it, or you will
    #   re-run the query against the server repeatedly.  This curious
    #   decision is made for consistency with RDF.rb.
    def run(&block)
      @repository.query(self, &block)
    end

    # Add a relation to this query.  Relations can only be used in Prolog
    # queries.
    #
    # @param [String] name
    # @param [Array<Symbol,RDF::Value,value>] arguments
    #   The arguments to the relation, which may be either variables,
    #   RDF::Value objects, or Ruby values that we can convert to literals.
    # @return [void]
    def relation(name, *arguments)
      # TODO: Don't abuse duck-typing quite so much.
      patterns << RDF::AllegroGraph::Query::Relation.new(name, *arguments)
    end

    # Generate all members of an actor's ego group.
    #
    # @param [RDF::Resource] actor The resource at the center of the graph.
    # @param [Integer] depth The maximum number of links to traverse.
    # @param [PrologLiteral] generator
    #   The generator to use when finding links to traverse.
    # @param [RDF::Query::Variable,RDF::Resource] member
    #   Either a
    #
    # @see Session#generator
    # @note This function adds a relation to a query.  The relation will
    #   be executed on the server when the query is run.
    def ego_group_member(actor, depth, generator, member)
      relation('ego-group-member', actor, PrologLiteral.new(depth),
               generator, member)
    end

    # Convert this query to AllegoGraph Prolog notation.
    #
    # @param [RDF::AllegroGraph::Repository] repository
    # @return [String]
    # @private
    def to_prolog(repository)
      variables = []
      relations = []
      patterns.each do |p|
        # Extract any new variables we see in the query.
        p.variables.each {|_,v| variables << v unless variables.include?(v) }
        relations << convert_to_relation(p).to_prolog(repository)
      end
      "(select (#{variables.join(" ")})\n  #{relations.join("\n  ")})"
    end

    protected

    # Convert patterns to relations (and leave relations unchanged).
    #
    # @param [RDF::Query::Pattern,Relation] pattern_or_relation
    # @return [Relation]
    # @private
    def convert_to_relation(pattern_or_relation)
      case pattern_or_relation
      when Relation then pattern_or_relation
      else
      p = pattern_or_relation
        if p.optional? || p.context
          raise ArgumentError.new("Can't translate #{p} to Prolog relation")
        end
        Relation.new('q-', p.subject, p.predicate, p.object)
      end
    end
  end
end
