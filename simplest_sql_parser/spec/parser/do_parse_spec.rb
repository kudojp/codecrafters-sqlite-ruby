# NOTE1: This spec does not mock the lexer used in SimplestSqlParser::Parser.
#        That is, this tests SimplestSqlParser::Parser with SimplestSqlParser::Parser used in it.
# NOTE2: Node#==() is overwritten to compare two nodes properly.
#        See the comment of Node#==.
RSpec.describe SimplestSqlParser::Parser do
  context "when query includes only SELECT statement" do
    it "generates the AST" do
      ast = described_class.new("SELECT name").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "name")
              )
            ]
          ),
          from_clause: nil,
          where_clause: nil
        )
      )
    end
  end

  context "when query includes SELECT, FROM statement" do
    it "generates the AST" do
      ast = described_class.new("SELECT name FROM table").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "name")
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: nil
        )
      )
    end

    it "generates the AST" do
      ast = described_class.new("SELECT name, address, age FROM table").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "name")
              ),
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "address")
              ),
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "age")
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: nil
        )
      )
    end

    it "generates the AST" do
      ast = described_class.new("SELECT * FROM table").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :asterisk, name: nil)
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: nil
        )
      )
    end
  end

  context "when query includes SELECT, FROM, WHERE statement" do
    it "generates the AST" do
      ast = described_class.new("SELECT name, address FROM table WHERE city = 'TOKYO'").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "name")
              ),
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "address")
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: AST::WhereClauseNode.new(
            predicate: [
              AST::ConditionNode.new(
                operator: :equals,
                left: AST::SelectedColumnNode.new(
                  col_def: AST::ColumnNode.new(type: :single_col, name: "city")
                ),
                right: AST::ExpressionNode.new(
                  value: "TOKYO"
                )
              )
            ]
          )
        )
      )
    end
  end

  context "when a query includes COUNT function" do
    it "generates the AST" do
      ast = described_class.new("SELECT COUNT(*) FROM table WHERE id = 12.5").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::FunctionNode.new(
                  type: :count,
                  args: [AST::ColumnNode.new(type: :asterisk, name: nil)]
                  )
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: AST::WhereClauseNode.new(
            predicate: [
              AST::ConditionNode.new(
                operator: :equals,
                left: AST::SelectedColumnNode.new(
                  col_def: AST::ColumnNode.new(type: :single_col, name: "id")
                ),
                right: AST::ExpressionNode.new(
                  value: 12.5
                )
              )
            ]
          )
        )
      )
    end
  end

  # TODO: This is a known issue.
  xcontext "WHEN an integer is surrounded by a single quote (e.g. '1212')" do
    it "generates the AST" do
      ast = described_class.new("SELECT name, address FROM table WHERE phone_number = '1212'").do_parse
      expect(ast).to eq(
        AST::QueryNode.new(
          select_clause: AST::SelectClauseNode.new(
            selected_columns: [
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "name")
              ),
              AST::SelectedColumnNode.new(
                col_def: AST::ColumnNode.new(type: :single_col, name: "address")
              )
            ]
          ),
          from_clause: AST::FromClauseNode.new(
            from_table: AST::FromTableNode.new(
              table_def: AST::TableNode.new(name: "table")
            )
          ),
          where_clause: AST::WhereClauseNode.new(
            predicate: [
              AST::ConditionNode.new(
                operator: :equals,
                left: AST::SelectedColumnNode.new(
                  col_def: AST::ColumnNode.new(type: :single_col, name: "phone_number")
                ),
                right: AST::ExpressionNode.new(
                  value: "1212" ################### -> This becomes "12.12" in a generated node.
                )
              )
            ]
          )
        )
      )
    end
  end
end
