%{
#include <cstdio>
#include <list>
#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/IRBuilder.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;

static Module *M = nullptr;
static LLVMContext TheContext;
static IRBuilder<> Builder(TheContext);

extern FILE *yyin;
int yylex();
void yyerror(const char*);

//std::map<std::string,Value*> idMap;
map<string, Value*> idMap;

extern "C" {
  int yyparse();
}


BasicBlock *BBjoin = nullptr;

  typedef struct {
    BasicBlock *then;
    BasicBlock *expr;
    BasicBlock *exit;
    BasicBlock *body;
    BasicBlock *join;
} control_helper;

%}

// %verbose
// %define parse.trace

%union {
  int reg;
  int imm;
  Value *val;
  char *id;
  vector<string> *args;
  vector<Value*> *valVec;
  BasicBlock *bb;
  control_helper blocks;
}
// Put this after %union and %token directives
%type <args> arglist arglist_opt
%token <id> IDENTIFIER
%type <val> expr
%token <reg> REG
%token <reg> ARG
%token <imm> IMMEDIATE     
%token ASSIGN SEMI PLUS MINUS LPAREN RPAREN LBRACE RBRACE COMMA MULTIPLY DIVIDE NOT IF WHILE
%token RETURN

%type <valVec> exprlist exprlist_opt
%type expr

%right NOT
%left MULTIPLY DIVIDE
%left PLUS MINUS

//arglist_opt : arglist
//{
  //$$ = $1;
//}
//| %empty
//{
  //$$ = new vector<string>;
//};


//arglist : IDENTIFIER
//{
  //$$ = new vector<string>;
  //$$->push_back($1); // remember IDENTIFIER
//}
//| arglist COMMA IDENTIFIER
//{
  //$$ = $1;
  //$$->push_back($3); //remember IDENTIFIER
//}
//;

//%type exprarglist_opt : arglist
//{
  //$$ = $1;
//}
//| %empty
//{
  //$$ = new vector<string>;
//};


//arglist : IDENTIFIER
//{
  //$$ = new vector<string>;
  //$$->push_back($1); // remember IDENTIFIER
//}
//| arglist COMMA IDENTIFIER
//{
  //$$ = $1;
  //$$->push_back($3); //remember IDENTIFIER
//}
//;


%%

program : function
| program function
| program SEMI SEMI // end of file
{
  return 0;
}
;

function: IDENTIFIER LPAREN arglist_opt RPAREN
{
  vector<string> &idVec = *$3;
 Type *i32 = Builder.getInt32Ty();

  std::vector<Type*> args;

  for(int i=0; i<idVec.size(); i++) {
    args.push_back(i32);
  }

  // Create i32 return function type with arguments
  FunctionType *FunType =
    FunctionType::get(Builder.getInt32Ty(),args,false);

  // Create a main function
  Function *Function = Function::Create(FunType,
                                        GlobalValue::ExternalLinkage,$1,M);

  //Add a basic block to main to hold instructions
  BasicBlock *BB = BasicBlock::Create(TheContext, "entry",
                                      Function);
  // Ask builder to place new instructions at end of the
  // basic block
  Builder.SetInsertPoint(BB);


  for (int i=0; i<idVec.size(); i++) {
    // Look to see if we already allocated it
    Value* var = NULL;
    if (idMap.find(idVec[i])==idMap.end()) {
     // We haven't so make a spot on the stack
      var = Builder.CreateAlloca(Builder.getInt32Ty(),
                                 nullptr,idVec[i]);
     // remember this location and associate it with $1
      idMap[idVec[i]] = var;
    } else {
      yyerror("repeat declaration of same variable!");
      return 1;
    }

    Builder.CreateStore(Function->getArg(i),var);
  }


}
LBRACE stmtlist RBRACE
;

arglist_opt : arglist
{
  $$ = $1;
}
| %empty
{
  $$ = new vector<string>;
};


arglist : IDENTIFIER
{
  $$ = new vector<string>;
  $$->push_back($1); // remember IDENTIFIER
}
| arglist COMMA IDENTIFIER
{
  $$ = $1;
  $$->push_back($3); //remember IDENTIFIER
}
;
stmtlist :    stmt
           |  stmtlist stmt

;

stmt: IDENTIFIER ASSIGN expr SEMI              /* expression stmt */
{
 Value* var = NULL;
  if (idMap.find($1)==idMap.end()) {
     var = Builder.CreateAlloca(Builder.getInt32Ty(),
                               nullptr,$1);
     // remember this location and associate it with $1
    idMap[$1] = var;
  } else {
    var = idMap[$1];
  }
  // store $3 into $1's  location in memory
  Builder.CreateStore($3,var);
}

| IF LPAREN expr RPAREN
{
//  1. Make join block and then block
  Function *F = Builder.GetInsertBlock()->getParent();

  BasicBlock *then = BasicBlock::Create(TheContext,
                     "if.then",F);
  BasicBlock *join = BasicBlock::Create(TheContext,
                     "if.join",F);

  Builder.CreateCondBr(
            Builder.CreateICmpNE($3,Builder.getInt32(0)),
            then,join);
  // 4. position builder in then-block
  Builder.SetInsertPoint(then);
  $<blocks>$.join = join;
  $<blocks>$.then = then;

}

LBRACE stmtlist RBRACE /* if stmt */
{

// merge back to join block
  //  1. find join block
  //  2. insert branch to join block
  Builder.CreateBr($<blocks>5.join);
  //  3. position builder in join block
  Builder.SetInsertPoint($<blocks>5.join);

}
| WHILE LPAREN
{
 Function *F = Builder.GetInsertBlock()->getParent();

 BasicBlock *expr =
     BasicBlock::Create(TheContext,"w.expr",F);
  Builder.CreateBr(expr);
  Builder.SetInsertPoint(expr);
  $<blocks>$.expr = expr;

}
expr RPAREN
{
  Function *F = Builder.GetInsertBlock()->getParent();
  BasicBlock *body =      
    BasicBlock::Create(TheContext,"w.body",F);
    BasicBlock *exit =
     BasicBlock::Create(TheContext,"w.exit",F);
 Builder.CreateCondBr(Builder.CreateICmpNE($4, Builder.getInt32(0)),body,exit);
Builder.SetInsertPoint(body);


  $<blocks>3.exit = exit;
  $<blocks>3.body = body;


}
LBRACE stmtlist RBRACE /*while stmt*/
{
  Builder.CreateBr($<blocks>3.expr);
  Builder.SetInsertPoint($<blocks>3.exit);
}

| SEMI /* null stmt */
| RETURN expr SEMI
{
  Builder.CreateRet($2);
}
;

exprlist_opt : exprlist
{

 $$ = $1;

}
| %empty
{
  $$ = new vector<Value*>;
}
;

exprlist : expr
{
 $$ = new vector<Value*>;
 $$->push_back($1);

}

| exprlist COMMA expr
{

  $$ = $1;
  $$->push_back($3);
}
;

expr: IMMEDIATE
{
  Value *v = Builder.getInt32($1);
  $$ = v;
}
| IDENTIFIER
{
  Value * alloca = idMap[$1];
  if (alloca == nullptr) {
     yyerror("Using a variable that hasn't been given a value.");
     return 0;
   }
   $$ = Builder.CreateLoad(Builder.getInt32Ty(), alloca, $1);

}
| IDENTIFIER LPAREN exprlist_opt RPAREN
{
 //function call rule

   Function *F = M->getFunction($1);
   if (F == nullptr) {
     yyerror("Function not declared or defined.");
     YYABORT;
   }

  $$ = Builder.CreateCall(F,*$3);


}
| expr PLUS expr
{
  $$ = Builder.CreateAdd($1, $3);
}
| expr MINUS expr
{
  $$ = Builder.CreateSub($1, $3);
}
| expr MULTIPLY expr
{
  $$ = Builder.CreateMul($1, $3);
}
| expr DIVIDE expr
{
  $$ = Builder.CreateSDiv($1, $3);
}
| MINUS expr
{
  $$ = Builder.CreateNeg($2);
}
| NOT expr
{
  Value *icmp = Builder.CreateICmpEQ($2,Builder.getInt32(0));
  $$ = Builder.CreateZExt(icmp,Builder.getInt32Ty());

}
| LPAREN expr RPAREN
{
  $$ = $2;
}
;

%%

void yyerror(const char* msg)
{
  printf("%s",msg);
}

int main(int argc, char *argv[])
{
  //yydebug = 0;
  yyin = stdin; // get input from screen

  // Make Module
  M = new Module("Tutorial4", TheContext);

  if (yyparse()==0) {
    // parse successful!
    std::error_code EC;
    raw_fd_ostream OS("main.bc",EC,sys::fs::OF_None);
    WriteBitcodeToFile(*M,OS);

    // Dump LLVM IR to the screen for debugging                           
    M->print(errs(),nullptr,false,true);
  }

  return 0;
}
